require "./libs/modules/toolbox"

class SimilarKeywords

  include Toolbox

  def initialize(options)
    @twitter = options[:twitter]
    @max_recursive_depth = options[:max_recursive_depth] || 2
    @keywords = []
    @searched_keywords = []
  end


  def get_keywords
    keywords = @keywords.flatten.uniq
    #log keywords, "keywords"
    return keywords
  end


  def add_keywords(keywords)
    @keywords << keywords
  end


  # Ensure that given array of keywords is saved in @searched_keywords
  # keywords => ["a", "b", ...]
  def mark_keywords_as_searched(keywords)
    keywords = [keywords] if keywords.class != [].class
    @searched_keywords << keywords.flatten.uniq
    @searched_keywords = @searched_keywords.flatten.uniq
  end



  # Check if the given keywords are not already searched
  # Returns array of un-searched keywords
  # keywords => ["a", "b", ...]
  def get_unsearched_keywords(keywords)
    keywords = [keywords] if keywords.class != [].class
    return (keywords - @searched_keywords)
  end



  # keywords => ["a", "b", ...]
  # Returns self for chaining
  def find_more_keywords_like(source_keywords, recursive_depth = 0)
    return_value = self
    unsearched_source_keywords = get_unsearched_keywords(source_keywords)

    return return_value if unsearched_source_keywords.length == 0

    mark_keywords_as_searched(unsearched_source_keywords)
    tweets = @twitter.search_tweets(unsearched_source_keywords, "OR", {:include_images => false, :exclude_links => true})
    keywords = find_new_keywords(tweets, unsearched_source_keywords)
    add_keywords(keywords)

    #log keywords, "Found keywords (RDepth=#{recursive_depth})"

    if (recursive_depth < @max_recursive_depth)
      keywords.each { |keyword|
        find_more_keywords_like([keyword], recursive_depth+1)
      }
    end
    
    return return_value
  end



  # Find all unique hashtags in a tweet
  def find_new_keywords(tweets, source_keywords)
    all_hashtags = []
    tweets.each { |tweet|
      if @twitter.is_retweetable?(tweet) == true
        all_hashtags << @twitter.hashtags_in_a_tweet(tweet)
      end
    }
    return all_hashtags.flatten.uniq
  end
  

end