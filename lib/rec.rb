require 'nokogiri'
require 'open-uri'
require 'uri'
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
    comment_title = content.parent.parent.parent.css(".comment-title").text.gsub("Re: #{original_title}", "")
    comment_title_tags = comment_title.gsub(/-/, "").split(",").map {|x| x.strip.gsub(/\s/, ".")}
    comment_css_id = content.parent.parent.parent.parent.attribute("id").value.gsub(/comment-/, "")
    comment_html = content.inner_html.gsub(/<\/?wbr>/, "")

    urls = URI.extract(comment_html, ['http'])

    urls = urls.map do |x|
      x = clean_detected_url(x)
      url_is_invalid?(x) ? nil : x
    end.compact

    urls.map do |url|
      if open_rec_urls
        title = Nokogiri::HTML(open(url.dup)).title.strip
      else
        title = comment_title
      end

      # If there's one rec, include the entire comment. Otherwise, get 
      # the paragraph the comment is in (paragraph determined by a double
      # line-break)

      if urls.size == 1
        description = comment_html.gsub(url, "")
      else
        broken_up_comment = comment_html.split("<br><br>")
        description = broken_up_comment.detect{|x| x.include?(url)}
      end

      description += "\n\n#{comment_css_id}"

      Rec.new(:url => url, 
              :description => description, 
              :tags => initial_tags + comment_title_tags, 
              :title => title)
    end
  end

  def self.parse_multi_rec_comment(content, urls)
    result = []

    text = content.inner_html.gsub(/<\/?wbr>/, "").split("<br><br>")
    #binding.pry if content.text =~ /I liked this one/

    urls.each do |url|
      # just gets the first text node that contains the url, because lol all the lols
      description =  text.detect{|x| x.include?(url)}
      result << Rec.new(:url => url, :description => description.gsub(url, ""))
    end

    result
  end

  # Tags is an array
  def initialize(params)
    @url = params[:url]
    @description = clean_description(params[:description])
    @tags = params[:tags]

    # should be able to pull the fandom out of the title too if it's from ao3
    @title = params[:title]
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

    url
  end

  # It's common for the link to end in a colon so... yeah
  # Just general cleanup of descriptions to convert it into something 
  # that looks nice.
  def clean_description(text)
    text.gsub("()", "").gsub("<br>", "\n").strip.chomp(":").chomp("-").strip
  end
end