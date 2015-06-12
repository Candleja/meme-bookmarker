require './lib/parsers/fansite_parser'
require './lib/parsers/ao3_parser'
require './lib/parsers/ffn_parser'
require './lib/parsers/lj_parser'
class Interpreter

  def initialize(opts={})
    @source_filter = opts[:source_filter] # To only parse recs from one source

    @ao3_parser = AO3Parser.new({:ask_human => opts[:ask_human]})
    @ffn_parser = FFNParser.new({:ask_human => opts[:ask_human]})
    @lj_parser = LJParser.new({:ask_human => opts[:ask_human]})
  end

  # Takes a comment node (class .comment-content) and returns 
  # an array of Recs
  def extract_recs_from_comment(content, opts={})

    # Whether or not we want to open the recced URL to get the page title
    open_rec_urls = opts[:open_rec_urls]
    original_title = opts[:original_title] || ""
    initial_tags = opts[:initial_tags] || []
    show_full_comment_url = opts[:show_full_comment_url]

    # Convert the title of the comment into tags
    # The original_title gsub won't work if a nonnie changes the comment from what the first
    # post is
    comment_title = content.parent.parent.parent.css(".comment-title").text
    comment_title = if first_depth_replies?(initial_tags)
                      comment_title.gsub("Re: #{original_title}", "") 
                    else
                      comment_title.gsub("Re: ", "")
                    end
    comment_title_tag = ".title:" + comment_title.gsub(/-/, "").strip.gsub(/\s/, '.')

    comment_css_id = content.parent.parent.parent.parent.attribute("id").value.gsub(/comment-/, "")
    comment_url = content.parent.parent.parent.css(".commentpermalink a").first.attribute("href")
    comment_html = content.inner_html.gsub(/<\/?wbr>/, "")


    comment_identifier = show_full_comment_url ? comment_css_id : comment_url

    urls = URI.extract(comment_html, ['http', 'https'])

    urls = urls.map do |x|
      x = clean_detected_url(x)
      url_is_invalid?(x) ? nil : x
    end.compact

    urls.map do |url|
      if open_rec_urls
        access_url = get_access_url(url)
        page = Nokogiri::HTML(open(access_url.dup, :allow_redirections => :safe))
        metadata_parser = get_metadata_parser(page, url)
      else
        access_url = url
        page = nil
        metadata_parser = nil
      end

      title = page ? (page.title.strip rescue comment_title) : comment_title

      tags_from_metadata = []

      tags_from_metadata += parse_fandom_tags(metadata_parser) rescue binding.pry
      tags_from_metadata += parse_pairing_tags(metadata_parser) rescue binding.pry
      tags_from_metadata += parse_trope_tags(metadata_parser) rescue binding.pry
      tags_from_metadata += parse_length_tags(metadata_parser) rescue binding.pry
      tags_from_metadata += parse_rating_tags(metadata_parser) rescue binding.pry
      #tags_from_metadata += parse_collection_tags(metadata_parser)

      user_summary        = parse_user_summary(metadata_parser) 

      # If there's one rec, include the entire comment. Otherwise, get 
      # the paragraph the comment is in (paragraph determined by a double
      # line-break)

      if urls.size == 1
        description = comment_html.gsub(url, "")
      else
        description = extract_description_for_url(comment_html, url)
      end

      description += "\r\n\r\n#{user_summary}\r\n\r\n#{comment_identifier}"
      rec = Rec.new(:url => access_url, 
              :description => description, 
              :tags => initial_tags + [comment_title_tag] + tags_from_metadata, 
              :title => title)

    end
  end

  # Some users separate their recs with a double-break, while others
  # choose not to, and we have to account for each case.
  def extract_description_for_url(comment_html, url)
    broken_up_comment = comment_html.split("<br><br>")

   
    description = broken_up_comment.detect{|x| x.include?(url)}

    # If there's only one URL when we use a double-break, then let's
    # keep that.
    if URI.extract(description, ['http', 'https']).size == 1
      description
    # Otherwise, someone posted a list of URLs, so we want only the block
    # containing that one URL, and the block of text before it too (unless 
    # there is a URL in it).
    else
      index_of_url_block = broken_up_comment.index(description)
      # Also grab only the individual URL we want, not all of them
      description = description.split("<br>").detect{|x| x.include?(url)}

      broken_up_comment[0..index_of_url_block].reverse.each do |x|
        if URI.extract(x, ['http', 'https']).empty?
          description = x + "<br>" + description
        end
      end

      # If there are no other text blocks with links in them, throw the
      # text after the link block into the description too.
      unless broken_up_comment[(index_of_url_block+1)..-1].detect{|x| 
        !URI.extract(x, ['http', 'https']).empty? }
        description += broken_up_comment[(index_of_url_block+1)..-1].join("<br>")
      end

      description
    end
  end

  # If the first reply to the thread OP is a request, we don't want
  # to keep the OP's original thread title, but if the OP is itself
  # a request, we keep it. This is usually the case for anything
  # that isn't the ffa_ficrecs post type.
  def first_depth_replies?(initial_tags)
    return initial_tags.detect{|x| x == "ffa_ficrecs"}
  end

  def debug_this_comment?(text)
    return false #text.include?("Metallic_Sweet") || text.include?("three-wishes-tw")
  end

  def url_is_invalid?(url)
    url !~ /http/ || restricted_domain?(url)
  end

  def restricted_domain?(url)

    # The source filter blocks all URLs that are not the given source
    if @source_filter
      case @source_filter
      when :ffn
        return url !~ /fanfiction.net/
      when :ao3
        return url !~ /archiveofourown/
      when :lj
        return url !~ /livejournal.com/
      end
    end

    [/fail-fandomanon/i,
    /youtube\.com/i].each do |blocked_domain|
      return true if url =~ blocked_domain
    end
    false
  end


  # Stuff like http://archiveofourown.org/works/914821/c or 
  # desert.http://archiveofourown.org/works/90443Sun, basically
  # TODO: add one for ff.n
  def clean_detected_url(url)
    # Chops off trailing non-digit characters if any are present in an AO3 link
    if url =~ /archiveofourown.org\/(works|series)\/\d+\D+/i
      url.sub!(/(\d)\D+$/, '\1')
    elsif url =~ /livejournal.com\/\d+.html[[:alnum]]+/i
      url.sub!(/html[[:alnum]]+$/, 'html')
    end

    url.gsub!(/[\)\.\,]+$/, "")
    url
  end

  # We can't modify the URL before we gsub it 
  def get_access_url(url)
    if url =~ /fanfiction.net/
      url.sub(/http:/, "https:")
    elsif url =~ /archiveofourown.org/
      url.sub(/https:/, "http:")
    else
      url
    end
  end

  def get_metadata_parser(page, url)
    parser = if url =~ /archiveofourown.org/
      @ao3_parser
    elsif url =~ /fanfiction.net/
      @ffn_parser
    elsif url =~ /livejournal.com/
      @lj_parser
    end
    parser.set_page_and_url(page, url)
    parser
  end

  def parse_fandom_tags(parser = nil)
    parser.try(:fandom_tags) || [".fandom:unknown"]
  end

  def parse_pairing_tags(parser = nil)
    parser.try(:pairing_tags) || [".pairing:unknown"]
  end

  def parse_trope_tags(parser = nil)
    parser.try(:trope_tags) || [".trope:unknown"]
  end

  def parse_length_tags(parser = nil)
    parser.try(:length_tags) || [".length:unknown"]
  end

  def parse_rating_tags(parser = nil)
    parser.try(:rating_tags) || [".rating:unknown"]
  end

  def parse_collection_tags(parser = nil)
    parser.try(:collection_tags) || []
  end

  def parse_user_summary(parser = nil)
    parser.try(:get_user_summary) || ""
  end

  def flush_metadata_updates
    @ao3_parser.flush_metadata_updates
    @ffn_parser.flush_metadata_updates
  end

end