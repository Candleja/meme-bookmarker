require "./lib/crawler"
require 'cgi'

link = "http://fail-fandomanon.dreamwidth.org/141763.html?thread=746494915"
crawler = Crawler.new
result = crawler.crawl(link, false)
