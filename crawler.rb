require "./lib/crawler"
require 'cgi'

link = "http://fail-fandomanon.dreamwidth.org/141210.html?thread=743342490"
crawler = Crawler.new
result = crawler.crawl(link, false)
