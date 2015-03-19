module StringMethods


  # Given a text, if search keywords exist in it, make the hashtags
  def add_hashtags(text, search_keywords)
    search_keywords.each { |keyword|
      text.gsub!(/#{keyword}/i, "##{keyword}")
    }
    return text
  end


  def stringify(obj)
    return obj.to_s
  end


  # Returns true if the given text has any of the given keywords
  # keywords => Any sort of array of keywords. Will be flattened, hashes will be removed
  # Atleast min_matching keywords should match, defaults to >1
  def text_has_keywords?(text, keywords, min_matching = 1)
    search_pattern = keywords.flatten.uniq.join("\b|").downcase.gsub("#", "")
    return text.scan(/#{search_pattern}/).uniq.length > 1 ? true : false
  end  


  # Given a string like "coffee wallpapers", convert to ["#coffee", "#wallpapers"]
  def sentence_to_tags(text, separator = " ")
    return text.split(separator).collect { |keyword| "##{keyword}" }
  end

end