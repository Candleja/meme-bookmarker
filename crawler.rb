require "./lib/crawler"
require "./lib/rec"
require 'cgi'

use_sample_source = false
open_rec_urls = true
links = [

]

crawler = Crawler.new(:export_format => "json", 
                      :use_sample_source => use_sample_source,
                      :open_rec_urls => open_rec_urls)

links.each do |link|
  p "Crawling #{link} now!"
  crawler.crawl(link)
end


