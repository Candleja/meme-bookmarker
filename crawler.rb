require "./lib/crawler"
require "./lib/rec"
require "./lib/interpreter"
require 'cgi'

class Object
  def try(*a, &b)
    try!(*a, &b) if a.empty? || respond_to?(a.first)
  end

  def try!(*a, &b)
    if a.empty? && block_given?
      if b.arity.zero?
        instance_eval(&b)
      else
        yield self
      end
    else
      public_send(*a, &b)
    end
  end
end

use_sample_source = false
open_rec_urls = true
limit = nil
ask_human = true
source_filter = nil #:lj
show_full_comment_url = true
links = [
  "http://fail-fandomanon.dreamwidth.org/145320.html?thread=766996136" #231
]

crawler = Crawler.new(:export_format => "json", 
                      :use_sample_source => use_sample_source,
                      :open_rec_urls => open_rec_urls,
                      :limit => limit,
                      :ask_human => ask_human,
                      :source_filter => source_filter,
                      :show_full_comment_url => show_full_comment_url)

links.each do |link|
  p "Crawling #{link} now!"
  crawler.crawl(link)
end


