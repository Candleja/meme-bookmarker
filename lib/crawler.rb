require 'nokogiri'
require 'pinboard'
require 'open-uri'
require 'fileutils'
require 'pry'
require 'uri'

class Crawler

  def initialize(opts)
    @export_format = opts[:export_format]
    @use_sample_source = opts[:use_sample_source]
    @open_rec_urls = opts[:open_rec_urls]
    @limit = opts[:limit]
    @interpreter = Interpreter.new(opts)
  end

  def use_sample_source
    @use_sample_source
  end

  def open_rec_urls
    @open_rec_urls
  end

  def limit
    @limit
  end

  def debug
    use_sample_source || !open_rec_urls || limit
  end

  def crawl(link)
    if use_sample_source
      page = Nokogiri::HTML(File.open('examples/sample_comment_parsing.html'))
    else
      link << "&expand_all=1" unless link =~ /&expand_all=1/
      page = Nokogiri::HTML(open(link.dup))
    end

    # Data about the source post
    original_title = page.css(".comment-depth-1 .comment-title").first.text

    id_tags = get_id_tags(link, page.title, original_title)

    rec_options = {:open_rec_urls => open_rec_urls, 
                   :original_title => original_title,
                   :initial_tags => id_tags}


    @recs = []

    #Grab all urls including from the OP
    comments = page.css(".comment-depth-1 .comment .inner .comment-content")
    
    comments.each do |reply|
      # An array of Rec objects with the relevant data
      @recs += @interpreter.extract_recs_from_comment(reply, rec_options)

      if limit and @recs.size >= limit
        @recs = @recs[0..limit-1]
        break
      end
    end

    file_name = id_tags.join + (debug ? "-debug" : "")
    case @export_format
    when "html"
      do_html_export(file_name, link)
    when "json"
      do_json_export(file_name)
    end

    @interpreter.flush_metadata_updates
  end


  def get_id_tags(url, post_title, thread_title)
    post_type = get_post_type(thread_title)

    tags = []
    tags << post_type if post_type

    # I can't believe no try in here whyyyy
    # check the post number -- if no number, then goes by title
    matched_post = post_title.match(/post ?#? ?(\d+)(\D|\Z)/i)
    post_number = matched_post ? matched_post[1] : post_title.gsub("fail_fandomanon | ", "").gsub(/\s/, ".")
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

  def get_post_type(thread_title)
    if thread_title =~ /fic rec/i
      "ffa_ficrecs"
    elsif thread_title =~ /reverse fic rec/i || thread_title =~ /unsolicited fic rec/i
      "ffa_unsolicted_ficrecs"
    elsif thread_title =~ /kink/i
      "ffa_kink"
    elsif thread_title =~ /porn/i || thread_title =~ /hot/i
      "ffa_porn"
    else
      "ffa_informal"
    end
  end

  def do_html_export(file_name, title)
    builder = Nokogiri::HTML::DocumentFragment.parse ""
    Nokogiri::HTML::Builder.with(builder) do |doc|
      doc.title title
    end

    list = Nokogiri::XML::Node.new "dl", builder


    # now we put it in the html
    @recs.each do |rec|
      list << rec.dt_node(builder)
      list << rec.dd_node(builder)
    end

    builder << list
    

    File.open("results/#{file_name}.html", "w") do |f|
      f << CGI.unescapeHTML(builder.to_html)
    end
  end

  def do_json_export(file_name)
    File.open("results/#{file_name}.json", "w") do |f|
      f << @recs.map(&:to_hash).to_json
    end
  end
end