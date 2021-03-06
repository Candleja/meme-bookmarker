require 'yaml'
require 'uri'
class FansiteParser
  def initialize(opts={})
    # Loads a mapping of AO3 tag -> pinboard tag
    @ask_human = opts[:ask_human]
    @fandom_mapping = YAML.load_file(File.open(File.join(reference_folder, "fandoms.yml")))
    @pairing_mapping = YAML.load_file(File.open(File.join(reference_folder, "pairings.yml")))
    @rating_mapping = YAML.load_file(File.open(File.join(reference_folder, "ratings.yml")))
    #@collections_mapping = YAML.load_file(File.open(File.join(reference_folder, "collections.yml")))
    #@tropes_mapping = YAML.load_file(File.open(File.join(reference_folder, "tropes.yml")))
  end

  def set_page_and_url(page, url)
    @page = page
    @url = url
  end

  def reference_folder
    raise "Set me!"
  end

  # Looks up from the reference file 
  def do_lookup(mapping, raw_tag)
    tag = mapping[raw_tag]
    name = mapping["name"]

    # Allow some found tags to never show, such as (one-sided) relationships or whatever
    if tag == "#{name}:hide"
      return nil
    end

    if !tag && @ask_human
      p "URL is #{@url}"
      p "Human input requested! Type xx to save tag preferences to file, yy to stop asking for human advice"
      p "Type hide to block the tag from requesting input again. Separate multiple tags with a space. "
      p "Please interpret for #{name} (don't prepend #{name} to the answer): #{URI.unescape(raw_tag)}"
      answer = gets.chomp

      while (answer == "xx")
        flush_metadata_updates
        answer = gets.chomp
      end

      unless answer.empty?
        if answer == "yy"
          @ask_human = false
        else
          tags = answer.split(" ").map{|x| "#{name}:#{x}" }
          result = if tags.size == 1
            tags.first
          else
            tags
          end
          mapping[raw_tag] = result if save_result
          return result unless result == "#{name}:hide"
        end
      end
    end

    tag
  end

  def save_result
    true
  end

  def get_user_summary
    return ""
  end

  def fandom_tags
    raw_tags = get_raw_fandom_tags
    tags = raw_tags.map do |t|
      do_lookup(@fandom_mapping, t)
    end.flatten.uniq.compact

    tags << ".fandom:unknown" if tags.empty?
    tags
  end

  def pairing_tags
    raw_tags = get_raw_pairing_tags
    tags = raw_tags.map do |t|
      do_lookup(@pairing_mapping, t)
    end.flatten.uniq.compact

    tags << ".pairing:unknown" if tags.empty?
    tags
  end
  
  def trope_tags
    [".trope:unknown"]
  end

  def length_tags
    raw_word_count = get_raw_word_count

    tag = if raw_word_count == 0
            ".length:unknown"
          elsif raw_word_count < 1000
            "length:0-1k"
          elsif raw_word_count < 5000
            "length:1k-5k"
          elsif raw_word_count < 10000
            "length:5k-10k"
          elsif raw_word_count < 25000
            "length:10k-25k"
          elsif raw_word_count < 50000
            "length:25k-50k"
          elsif raw_word_count < 100000
            "length:50k-100k"
          else
            "length:>100k"
          end
    [tag]
  end

  def rating_tags
    raw_tags = get_raw_rating_tags
    tags = raw_tags.map do |t|
      do_lookup(@rating_mapping, t)
    end.flatten.uniq.compact

    tags << ".rating:unknown" if tags.empty?
    tags
  end

  #Not implemented
  def collection_tags
    []
  end

  def flush_metadata_updates
    File.open(File.join(reference_folder, "fandoms.yml"), "w") do |f|
      f << @fandom_mapping.to_yaml
    end

    File.open(File.join(reference_folder, "pairings.yml"), "w") do |f|
      f << @pairing_mapping.to_yaml
    end

    File.open(File.join(reference_folder, "ratings.yml"), "w") do |f|
      f << @rating_mapping.to_yaml
    end
  end
end