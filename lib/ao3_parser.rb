# Takes an opened AO3 page and parses the data
require './lib/fansite_parser'
class AO3Parser < FansiteParser

  def reference_folder
    "reference/ao3/"
  end

  def get_user_summary
    return "" if needs_login?

    first_summary_type_block = @page.css("blockquote.userstuff").first

    if first_summary_type_block
      "Author Summary:\n" + first_summary_type_block.inner_html.gsub(/<p>/, "\n").gsub(/<\/p>/, "").strip
    end
  end

  def get_raw_fandom_tags
    all_fandom_tags = @page.css(".fandoms .tag, .fandom .tag").map do |x| 
      tag_url = x.attribute("href").value
      tag = get_tag_from_tag_url(tag_url)
    end.uniq
  end

  def get_raw_pairing_tags
    all_pairing_tags = @page.css(".relationships .tag, .relationship .tag").map do |x| 
      tag_url = x.attribute("href").value
      tag = get_tag_from_tag_url(tag_url)
    end.uniq
  end
  
  # Let's not auto-parse tropes for now.
  def get_raw_trope_tags
    return []
  end

  # Returns an int
  def get_raw_word_count
    num = 0

    if series? or individual_work? && !needs_login?
      word_index = @page.css("dl.stats dt").map(&:text).index("Words:")
      word_count = @page.css("dl.stats dd").map(&:text)[word_index] rescue binding.pry

      return 0 unless word_count

      word_count.gsub(",", "").to_i
    else
      0
    end
  end

  def get_raw_rating_tags
    unless series? or individual_work?
      return nil
    end

    tagged_ratings = @page.css(".rating .tag").map do |x| 
      tag_url = x.attribute("href").value
      tag = get_tag_from_tag_url(tag_url)
    end

    tagged_ratings += @page.css(".rating").map do |x| 
      x.attribute("title").try(:value )
    end

    tagged_ratings.compact.uniq

  end

  # Let's not do collections for now either
  def collection_tags
    return []
  end

  def series?
    @url.match(/archiveofourown.org\/series\/\d+/)
  end

  def individual_work?
    @url.match(/archiveofourown.org\/works\/\d+/)
  end

  def get_tag_from_tag_url(url)
    url.match(/\/tags\/(.+)\/works/)[1]
  end

  def needs_login?
    @page.css("#new_user_session").size > 1
  end

end