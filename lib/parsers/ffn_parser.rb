# Takes an opened fanfiction.net page and parses the data
class FFNParser < FansiteParser

  def reference_folder
    "reference/ffn/"
  end

  def get_user_summary
    "Author Summary:\n" + @page.css("#profile_top .xcontrast_txt")[5].text.strip
  end

  def get_raw_fandom_tags
    if individual_work?
      return [@page.css(".lc-left a").last.text]
    end

    []
  end

  def get_raw_pairing_tags
    if individual_work?
      characters = grey_metadata_bar.text.split(" - ")[3]

      # Sometimes an author doesn't specify a character, which means this field will be
      # the chapter count, which we can ignore.
      if characters =~ /Chapters:/
        []
      else
        # Grab all the character sets that are in [], which seem to denote romantic relationships.
        characters.scan(/\[.+?\]/)
      end
    else
      []
    end
  end
  
  # Let's not auto-parse tropes for now.
  def get_raw_trope_tags
    return []
  end

  # Returns an int
  def get_raw_word_count
    word_count = grey_metadata_bar.text.match(/Words: ([\d,]+) -/).try(:[], 1)

    if word_count
      word_count.gsub(",", "").to_i
    else
      0
    end
  end

  def get_raw_rating_tags
    if individual_work?
      return [grey_metadata_bar.css("a[target='rating']").text]
    end

    []

  end

  def individual_work?
    @url.match(/fanfiction.net\/s\/\d+/)
  end

  def user_page?
    @url.match(/fanfiction.net\/u\/\d+/)
  end

  # FF.N doesn't separate out its shit, because... reasons. So we have to grab the metadata bar
  # And then probably split it across the derpy little hyphens it uses as separators.
  def grey_metadata_bar
    @page.css(".xgray.xcontrast_txt")
  end


end