require "./lib/crawler"
require "./lib/rec"
require 'cgi'

use_sample_source = false
open_rec_urls = false
links = [
 #"http://fail-fandomanon.dreamwidth.org/141210.html?thread=743342490",
  #"http://fail-fandomanon.dreamwidth.org/141532.html?thread=744922076",
  "http://fail-fandomanon.dreamwidth.org/141763.html?thread=746494915"
]


links.each do |link|
  crawler = Crawler.new(:export_format => "html", 
                        :link => link, 
                        :use_sample_source => use_sample_source,
                        :open_rec_urls => open_rec_urls)
  crawler.crawl
end
