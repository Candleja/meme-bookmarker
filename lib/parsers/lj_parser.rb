# Takes an opened fanfiction.net page and parses the data
class LJParser < FansiteParser

  def reference_folder
    "reference/lj/"
  end

  def ask_for_additional_tags(name)
    return [] unless @ask_human

    p "Title is: #{post_title}"
    p "Url is: #{@url}"
    p "#{name} tags? (space-delimited, emptystring if unknown)"
    gets.chomp.split(" ")
  end

  def get_user_summary

    summary = nil
    if individual_work?
      #Pull the obvious ones ( if well labeled)
      post_head.each do |s|
        match = s.match(/summary: ?(.+)/i)
        if match
          summary = match[1]
          break
        end
      end
    end

    if summary
      "Author Summary:\n" + summary
    else
      ""
    end
  end

  def get_raw_fandom_tags

    if individual_work?
      #Pull the obvious ones ( if well labeled)
      post_head.each do |s|
        fandom = s.match(/fandom: ?(.+)/i)
        return fandom[1].split(",").map(&:strip) if fandom
      end
    end

    #Otherwise ask a human for additional ones (separated by spaces)
    ask_for_additional_tags("Fandom")
  end

  def get_raw_pairing_tags
    if individual_work?
      #Then ask a human for additional ones (separated by spaces)
      post_head.each do |s|
        pairing = s.match(/pairing: ?(.+)/i)
        return pairing[1].split(",").map(&:strip) if pairing
      end
    end

    ask_for_additional_tags("Pairing")
  end

  # Returns an int
  def get_raw_word_count
    post_head.each do |s|
      word_count = s.match(/(length|word count|size): ?(.+)/i)
      return word_count[1].gsub(",", "").to_i if word_count
    end
      
    ask_for_additional_tags("Word Count")[0].to_i
  end

  def get_raw_rating_tags
    if individual_work?
      #Then ask a human for additional ones (separated by spaces)
      post_head.each do |s|
        rating = s.match(/rating: ?(.+)/i)
        return rating[1].split(",").map(&:strip) if rating
      end
    end

    ask_for_additional_tags("Rating")
  end

  def individual_work?
    @url.match(/livejournal.com\/\d+/) && !comment_thread?
  end

  def comment_thread?
    @url.match(/thread=\d+/)
  end

  def user_page?
    @url.match(/livejournal.com\/profile/)
  end

  def post_title
    @page.title.strip
  end

  # The first chunk of the post, where there might be some info if author puts
  # a heading
  def post_head
    # might also be called asset_body
    @page.css(".entry-content").children[0..50].to_html.split("<br>").map{|x| x.gsub(%r{</?[^>]+?>}, '')}
  end

end