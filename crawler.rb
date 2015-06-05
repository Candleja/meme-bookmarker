require "./lib/crawler"
require "./lib/rec"
require 'cgi'

use_example_source = false
open_links = false
links = [
# "http://fail-fandomanon.dreamwidth.org/141210.html?thread=743342490",
#  "http://fail-fandomanon.dreamwidth.org/141532.html?thread=744922076",
  "http://fail-fandomanon.dreamwidth.org/141763.html?thread=746494915"
]
crawler = Crawler.new

links.each do |link|
  crawler.crawl(link, use_example_source, open_links)
end
