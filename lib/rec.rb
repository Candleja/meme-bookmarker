require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'uri'
require 'json'

class Rec
  DEFAULT_TAGS = ["needs_better_tags"]
  # Tags is an array
  def initialize(params)
    @url = params[:url]
    @description = clean_description(params[:description].gsub(@url, ""))
    @tags = params[:tags]
    @page = nil
    @title = params[:title]

    p "Creating rec for: #{@url}"
  end

  def tags
    DEFAULT_TAGS + @tags
  end

  def add_tag(tag)
    @tags << tag
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
    a_node[:tags] = tags.sort.join(" ")
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
      :tags => clean_string(tags.sort.join(" ")),
      :time => Time.now.to_s,
      :toread => "yes"
    }
  end

  protected

  # It's common for the link to end in a colon so... yeah
  # Just general cleanup of descriptions to convert it into something 
  # that looks nice.
  def clean_description(text)
    desc = text.gsub("()", "").gsub("<br>", "\r\n").strip.gsub(/[\:\-]+$\Z/, "").strip
  end

  # Now we have to fix the encoding because lol smart quotes
  def clean_string(text)
    text = text.gsub(/[“”]/, "\"").gsub(/[‘’]/, "'").gsub(/–/, "--")
    text = text.encode('ascii', :invalid => :replace, :undef => :replace)
    CGI.unescapeHTML(text)
  end
end