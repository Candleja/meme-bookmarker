require "./lib/crawler"
require 'cgi'

links = [
  "http://fail-fandomanon.dreamwidth.org/141210.html?thread=743342490",
  "http://fail-fandomanon.dreamwidth.org/141532.html?thread=744922076",
  "http://fail-fandomanon.dreamwidth.org/141763.html?thread=746494915"
]
crawler = Crawler.new

links.each do |link|
  crawler.crawl(link, true)
end
