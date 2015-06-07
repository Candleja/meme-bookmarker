require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'uri'
require 'json'
class Rec
  DEFAULT_TAGS = ["needs_better_tags"]


  # Takes a comment node (class .comment-content) and returns 
  # an array of Recs
  def self.extract_from_comment(content, opts={})

    # Whether or not we want to open the recced URL to get the page title
    open_rec_urls = opts[:open_rec_urls]
    original_title = opts[:original_title] || ""
    initial_tags = opts[:initial_tags] || []

    # Convert the title of the comment into tags
    # The original_title gsub won't work if a nonnie changes the comment from what the first
    # post is
    comment_title = content.parent.parent.parent.css(".comment-title").text
    comment_title = if first_depth_replies?(initial_tags)
                      comment_title.gsub("Re: #{original_title}", "") 
                    else
                      comment_title.gsub("Re: ", "")
                    end
    comment_title_tags = comment_title.gsub(/-/, "").split(",").map {|x| x.strip.gsub(/\s/, ".")}
    comment_css_id = content.parent.parent.parent.parent.attribute("id").value.gsub(/comment-/, "")
    comment_html = content.inner_html.gsub(/<\/?wbr>/, "")

    urls = URI.extract(comment_html, ['http', 'https'])

    urls = urls.map do |x|
      x = clean_detected_url(x)
      url_is_invalid?(x) ? nil : x
    end.compact

    urls.map do |url|
      if open_rec_urls
        title = Nokogiri::HTML(open(url.dup, :allow_redirections => :safe)).title.strip rescue comment_title
      else
        title = comment_title
      end

      # If there's one rec, include the entire comment. Otherwise, get 
      # the paragraph the comment is in (paragraph determined by a double
      # line-break)

      if urls.size == 1
        description = comment_html.gsub(url, "")
      else
        description = extract_description_for_url(comment_html, url)
      end

      description += "\r\n\r\n#{comment_css_id}"

      Rec.new(:url => url, 
              :description => description, 
              :tags => initial_tags + comment_title_tags, 
              :title => title)
    end
  end

  # Some users separate their recs with a double-break, while others
  # choose not to, and we have to account for each case.
  def self.extract_description_for_url(comment_html, url)
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
      index_of_url = broken_up_comment.index(description)
      # Also grab only the individual URL we want, not all of them
      description = description.split("<br>").detect{|x| x.include?(url)}

      broken_up_comment[0..index_of_url].reverse.each do |x|
        if URI.extract(x, ['http', 'https']).empty?
          description = x + description
        end
      end
      description
    end
  end

  # If the first reply to the thread OP is a request, we don't want
  # to keep the OP's original thread title, but if the OP is itself
  # a request, we keep it. This is usually the case for anything
  # that isn't the ffa_ficrecs post type.
  def self.first_depth_replies?(initial_tags)
    return initial_tags.detect{|x| x == "ffa_ficrecs"}
  end

  def self.debug_this_comment?(text)
    return false #text.include?("Metallic_Sweet") || text.include?("three-wishes-tw")
  end

  # Tags is an array
  def initialize(params)
    @url = params[:url]
    @description = clean_description(params[:description].gsub(@url, ""))
    @tags = params[:tags]

    # should be able to pull the fandom out of the title too if it's from ao3
    @title = params[:title]
    p "Creating rec: #{self}"
  end

  def tags
    DEFAULT_TAGS + @tags
  end

  def url
    @url
  end

  def title
    @title
  end

  def description
    @description
  end

  def dt_node(builder)
    dt_node = Nokogiri::XML::Node.new "dt", builder
    a_node =  Nokogiri::XML::Node.new "a", builder
    a_node[:href] = url
    a_node[:tags] = tags.join(" ")
    a_node[:private] = "1"
    # l o fucking l
    a_node.content = title
    dt_node << a_node

    dt_node
  end

  def dd_node(builder)
    description_node = Nokogiri::XML::Node.new "dd", builder
    description_node.content = description
    description_node
  end

  def to_s
    "#{url}: #{title}"
  end
  
  #{"href":"http:\/\/www.livejournal.com\/",
  #"description":"another test",
  #"extended":"what about break tags<br><br><br>and some <i>italics</i>?",
  #"shared":"no","tags":"import_test","time":"2015-06-05 22:49:30 -0700", 
  #{}"toread":"yes"}
  def to_hash
    # There's a bug in the pinboard importer that makes toread => "no" mark as 
    # unread right now
    {
      :href => clean_string(url),
      :description => clean_string(title),
      :extended => clean_string(description),
      :shared => "no",
      :tags => clean_string(tags.join(" ")),
      :time => Time.now.to_s,
      :toread => "yes"
    }
  end

  protected

  def self.url_is_invalid?(url)
    url !~ /http/ || url =~ /fail-fandomanon/
  end


  # Stuff like http://archiveofourown.org/works/914821/c or 
  # desert.http://archiveofourown.org/works/90443Sun, basically
  # TODO: add one for ff.n
  def self.clean_detected_url(url)
    # Chops off trailing non-digit characters if any are present in an AO3 link
    if url =~ /archiveofourown.org\/(works|series)\/\d+\D+/i
      url.sub!(/(\d)\D+$/, '\1')
    elsif url =~ /livejournal.com\/\d+.html[[:alnum]]+/i
      url.sub!(/html[[:alnum]]+$/, 'html')
    end

    url.gsub(/[\)\.]+$/, "")
  end

  # It's common for the link to end in a colon so... yeah
  # Just general cleanup of descriptions to convert it into something 
  # that looks nice.
  def clean_description(text)
    desc = text.gsub("()", "").gsub("<br>", "\r\n").strip.gsub(/[\:\-]+$/, "").strip
  end

  # Now we have to fix the encoding because lol smart quotes
  def clean_string(text)
    text = text.gsub(/[“”]/, "\"").gsub(/[‘’]/, "'").gsub(/–/, "--")
    text = text.encode('ascii', :invalid => :replace, :undef => :replace)
    CGI.unescapeHTML(text)
  end
end