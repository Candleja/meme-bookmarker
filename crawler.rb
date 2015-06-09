require "./lib/ao3_parser"
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
limit = 12
ask_human = true
links = [
  "http://fail-fandomanon.dreamwidth.org/141210.html?thread=743342490"
]

crawler = Crawler.new(:export_format => "json", 
                      :use_sample_source => use_sample_source,
                      :open_rec_urls => open_rec_urls,
                      :limit => limit,
                      :ask_human => ask_human)

links.each do |link|
  p "Crawling #{link} now!"
  crawler.crawl(link)
end


