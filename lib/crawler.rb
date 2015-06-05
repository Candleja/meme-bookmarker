require 'nokogiri'
require 'pinboard'
require 'open-uri'
require 'fileutils'
require 'pry'
require 'uri'

class Crawler

  STARTER_TAGS = ["needs_better_tags", "ffa_ficrecs"]
  def crawl(link, debug=true)

    if false #debug
      page = Nokogiri::HTML(File.open('examples/sample_source.html'))
    else
      link << "&expand_all=1" unless link =~ /&expand_all=1/
      page = Nokogiri::HTML(open(link.dup))
    end

    builder = Nokogiri::HTML::DocumentFragment.parse ""
    Nokogiri::HTML::Builder.with(builder) do |doc|
      doc.title link
    end

    list = Nokogiri::XML::Node.new "dl", builder


    # Data about the source post
    original_title = page.css(".comment-depth-1 .comment-title").first.text

    id_tags = get_id_tags(link, page.title, original_title)

    #top level comments are requests -- so we start parsing there
    requests = page.css(".comment-depth-2")
    requests.each do |request|
      replies = request.css(".comment .inner .comment-content")
      replies.each do |reply|
        # An array of hashes with the relevant data
        recs = parse_recs(reply)

        # Convert the title of the comment into tags
        # The original_title gsub won't work if a nonnie changes the comment from what the first
        # post is
        comment_title = reply.parent.parent.parent.css(".comment-title").text.gsub("Re: #{original_title}", "")
        comment_title_tags = comment_title.gsub(/-/, "").split(",").map {|x| x.strip.gsub(/\s/, ".")}
        comment_id = reply.parent.parent.parent.parent.attribute("id").value.gsub(/comment-/, "")

        # now we put it in the html
        recs.each do |rec|
          p "Adding rec: #{rec}"
          url = rec[:url]
          title = debug ? comment_title : Nokogiri::HTML(open(url.dup)).title.strip rescue comment_title
          tags = (id_tags + rec[:tags] + comment_title_tags).join(",")

          # should be able to pull the fandom out of the title too if it's from ao3

          dt_node = Nokogiri::XML::Node.new "dt", builder
          a_node =  Nokogiri::XML::Node.new "a", builder
          a_node[:href] = url
          a_node[:tags] = tags
          a_node[:private] = "1"
          # l o fucking l
          a_node[:original_url] = link + "##{comment_id}"
          a_node.content = title
          dt_node << a_node

          description_node = Nokogiri::XML::Node.new "dd", builder
          description_node.content = clean_description(rec[:description])
          list << dt_node
          list << description_node
        end
      end
    end

    builder << list
    
    file_name = id_tags.join + ".html"
    File.open(file_name, "w") do |f|
      f << CGI.unescapeHTML(builder.to_html)
    end
  end

  def parse_recs(content)
    urls = URI.extract(content.to_html.gsub(/<\/?wbr>/, ""), ['http'])

    urls = urls.map do |x|
      x = clean_detected_url(x)
      url_is_invalid?(x) ? nil : x
    end.compact

    if urls.size == 1
      url = urls.first
      [{:url => url, :description => content.text.gsub(url, ""), :tags => STARTER_TAGS}]
    else 
      parse_multi_rec_comment(content, urls)
    end
  end

  def parse_multi_rec_comment(content, urls)
    result = []

    text = content.inner_html.gsub(/<\/?wbr>/, "").split("<br>")
    #binding.pry if content.text =~ /I liked this one/

    urls.each do |url|
      # just gets the first text node that contains the url, because lol all the lols
      description =  text.detect{|x| x.include?(url)}
      result << {:url => url, :description => description.gsub(url, ""), :tags => STARTER_TAGS}
    end

    result
  end

  # Stuff like http://archiveofourown.org/works/914821/c or 
  # desert.http://archiveofourown.org/works/90443Sun, basically
  def clean_detected_url(url)

    # Chops off trailing non-digit characters if any are present in an AO3 link
    if url =~ /archiveofourown.org\/(works|series)\/\d+\D+/i
      url.sub!(/(\d)\D+$/, '\1')
    elsif url =~ /livejournal.com\/\d+.html[[:alnum]]+/i
      url.sub!(/html[[:alnum]]+$/, 'html')
    end

    url
  end

  def url_is_invalid?(url)
    url !~ /http/ || url =~ /fail-fandomanon/
  end

  # It's common for the link to end in a colon so... yeah
  def clean_description(text)
    text.strip.chomp(":").chomp("-").strip
  end

  def get_id_tags(url, post_title, thread_title)
    post_type = if thread_title =~ /fic rec/i
      "ficrecs"
    else
      nil
    end

    tags = []
    tags << post_type if post_type

    # I can't believe no try in here whyyyy
    # check the post number
    matched_post = post_title.match(/post ?# ?(\d+)\D/i)
    post_number = matched_post ? matched_post[1] : nil
    tags << "post:#{post_number}" if post_number

    # check the entry id (from the url)
    matched_entry = url.match(/.org\/(\d+)\D/)
    entry_id = matched_entry ? matched_entry[1] : nil
    tags << "entry:#{entry_id}" if entry_id

    # check the thread id (so we can tag multiple threads)
    matched_thread = url.match(/thread=(\d+)\D/)
    thread_id = matched_thread ? matched_thread[1] : nil
    tags << "thread:#{thread_id}" if thread_id

    tags
  end
end