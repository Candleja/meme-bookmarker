require "./lib/crawler"
require "./lib/rec"
require 'cgi'

use_sample_source = false
open_rec_urls = true
links = [
  "http://fail-fandomanon.dreamwidth.org/141210.html?thread=743342490",
  "http://fail-fandomanon.dreamwidth.org/141532.html?thread=744922076"
  #"http://fail-fandomanon.dreamwidth.org/141763.html?thread=746494915"
]

crawler = Crawler.new(:export_format => "json", 
                      :use_sample_source => use_sample_source,
                      :open_rec_urls => open_rec_urls)

links.each do |link|
  p "Crawling #{link} now!"
  crawler.crawl(link)
end
