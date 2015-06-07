require "./lib/crawler"
require "./lib/rec"
require 'cgi'

use_sample_source = false
open_rec_urls = true
links = [
  "http://fail-fandomanon.dreamwidth.org/28493.html?thread=124982349",
  "http://fail-fandomanon.dreamwidth.org/28393.html?thread=123954665",
  "http://fail-fandomanon.dreamwidth.org/27872.html?thread=121002720",
  "http://fail-fandomanon.dreamwidth.org/29368.html?thread=128763064"
]

crawler = Crawler.new(:export_format => "json", 
                      :use_sample_source => use_sample_source,
                      :open_rec_urls => open_rec_urls)

links.each do |link|
  p "Crawling #{link} now!"
  crawler.crawl(link)
end


