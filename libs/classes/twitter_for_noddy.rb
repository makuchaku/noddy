require "./libs/modules/toolbox.rb"
require 'chatterbot/dsl'

class TwitterForNoddy

  include Toolbox
  #include LisaToolbox

  attr_accessor :config, :bird_food_stats, :exclude_list

  # random_sleep_time = rand(SLEEP_AFTER_ACTION * multiplier) + SLEEP_AFTER_ACTION_BASE
  SLEEP_AFTER_ACTION = 60 # secs
  SLEEP_AFTER_ACTION_BASE = 60*5 # secs
  SLEEP_AFTER_RATE_LIMIT_ENGAGED = 60*5 # 2 min


  def initialize(config = {})
    # Safety net
    raise if config[:auth].nil?
    raise if config[:auth][:consumer_key].nil? or config[:auth][:consumer_secret].nil? or config[:auth][:token].nil? or config[:auth][:secret].nil?

    default_config = {
      :name => "Noddy",
      :auth => {
        :consumer_key => nil,
        :consumer_secret => nil,
        :token => nil,
        :secret => nil
      },
      :lang => "en", 
      :tweet => {
        :min_retweet_count => 2, 
        :min_star_count => 2,
        :moderate_retweet_count => 4,
        :moderate_star_count => 4,  
        :high_retweet_count => 6,
        :high_star_count => 6   # To get more starrable tweets into the honeypot :)
      },
      :user => {
        :followers_to_friends_ratio => 0.2,
        :min_followers_count => 100,
        :min_star_count => 5,
        :min_tweet_count => 150,
        :account_age => 0
      },
      :exclude => [], # Array of strings
      :max_count_per_search => 100
    }
    @recursive_search_count = 0

    @config = default_config.merge(config)

    # Setup the client
    consumer_key(@config[:auth][:consumer_key])
    consumer_secret(@config[:auth][:consumer_secret])
    token(@config[:auth][:token])
    secret(@config[:auth][:secret])

    setup_exclusions(@config[:exclude])

    @myself = client.user.handle

    # Numerical limits on outgoing actions
    @limits = {
      :run => {
        :follow => with_x_percentage_additional_random(10, 30),
        :star => with_x_percentage_additional_random(150, 50),
        :clone => with_x_percentage_additional_random(100, 50),
        :retweet => with_x_percentage_additional_random(50, 50)
      },
      :actuals => {
        :follow => 0,
        :star => 0,
        :clone => 0,
        :retweet => 0
      }
    }

    # ["#foo", "#bar"]
    @related_hashtags = []
    @all_hashtags = []
  end



  # Calls the given block with a sleeping factor of the rate limiting
  # Currently we don't care about the lost activity as we don't redo
  def rate_limit(where, &block)
    begin
      block.call
    rescue Twitter::Error::TooManyRequests => error
      puts "Rate limit engaged in #{where}, sleeping for #{error.rate_limit.reset_in} seconds #############################"
      sleep(error.rate_limit.reset_in + rand(SLEEP_AFTER_RATE_LIMIT_ENGAGED) + 10)
    rescue Exception => e
      puts "Got generic exception..."
      puts e
      puts e.backtrace      
    end
  end  



  # Generic logging
  def log(object, prefix="log")
    prefix.upcase!
    timestamp = Time.now.to_s.split(" ")[0..1].join(" ")
    if object.is_a?(Twitter::Tweet)
      pre = "[#{prefix}] [#{timestamp}] [ID:#{object.id} ST:#{object.favorite_count}, RT?:#{object.retweet?}, RT:#{object.retweet_count}, urls?:#{object.urls?}, media?:#{object.media?}, @M?:#{object.user_mentions?}, @Re?:#{object.reply?}] : [#{object.user.id}:@#{object.user.handle}]"
      puts "\n=> #{pre} => #{object.text}" 
    elsif object.is_a?(Twitter::User)
      pre = "[#{prefix}] [#{timestamp}] [Fo:#{object.followers_count}, Fr:#{object.friends_count}, \
              Fo/Fr:#{object.followers_count/object.friends_count.to_f}, St:#{object.favorites_count}, \
              Tw:#{object.tweets_count}] Handle=#{object.handle}"
      puts "\n=> #{pre}"       
    else
      puts "=> [#{timestamp}] [#{prefix}] #{object}"
    end
  end  





  # Remove those hashtags which are present in search source
  # source_hashtags => [["#aa", "#bb"], ...]
  # found_hashtags => ["#aa", "#bb", ...]
  def get_new_and_unique_hashtags(source_hashtags, found_hashtags)
    # normalize source hashtags
    source_hashtags = source_hashtags.flatten.join(",").downcase.split(",")
    hashtags = found_hashtags.uniq - source_hashtags
    results = []; hashtags.each {|tag| results << [tag] }
    return results
  end




  # NOTE - Actually does the stars
  def star(tweet, mode = :real)
    return false if check_hit?(:tweet_infested, tweet.id, :verbose) == true

    log(tweet, "STAR")
    return if mode == :preview

    record_hit(:tweet_infested, tweet.id)

    rate_limit(:star) { client.favorite(tweet.id) }
    random_sleep(SLEEP_AFTER_ACTION, 1, SLEEP_AFTER_ACTION) # We don't need to sleep so long after starring
  end




  # NOTE - Actually does the retweet
  def retweet(tweet, mode = :real)
    return false if check_hit?(:tweet_infested, tweet.id, :verbose) == true

    #log("Retweeting tweet (id=>#{tweet.id}) : [#{tweet.user.handle}] : #{tweet.text}")
    log(tweet, "RETWEET")
    return if mode == :preview

    record_hit(:tweet_infested, tweet.id)

    rate_limit(:retweet) { client.retweet(tweet.id) }
    random_sleep(SLEEP_AFTER_ACTION, 1, SLEEP_AFTER_ACTION_BASE)
  end




  # NOTE - Actually does the clone
  def clone(tweet, mode = :real)
    return false if check_hit?(:tweet_infested, tweet.id, :verbose) == true

    clone_text = tweet.text

    if tweet.text.index("@") != nil
      # Attribute the tweet to an end user only if it already has a @mention. 100% clone it otherwise
      clone_text = "#{tweet.text} via @#{tweet.user.handle}" if tweet.text.index("@") != nil
      clone_text = tweet.text if clone_text.length > 140 # revert back to original text if new length with "via .@foo" > 140
    end
    
    return if mode == :preview
    record_hit(:tweet_infested, tweet.id)
    rate_limit(:clone) {puts "cloning...."; client.update(clone_text) }

    random_sleep(SLEEP_AFTER_ACTION, 1, SLEEP_AFTER_ACTION_BASE)
  end   



  # NOTE - Does a status update on the current user
  def tweet_without_media(text, mode = :real)
    return if mode == :preview
    return if text.length > 140

    rate_limit(:tweet_without_media) {
      client.update(text) 
    }
  end



  # NOTE - Actually does the tweet with given media file
  # tweet => {:text => "text", :media_path => "/some/file/path"}
  def tweet_with_media(tweet, sleep_multiplier = 10, mode = :real)
    log(tweet, "tweet_with_media")
    return if mode == :preview
     
    rate_limit(:tweet_with_media) { 
      tweet[:media_path].nil? ? client.update(tweet[:text]) : client.update_with_media(tweet[:text], File.new(tweet[:media_path])) 
    }
    random_sleep(SLEEP_AFTER_ACTION, 1, SLEEP_AFTER_ACTION*sleep_multiplier)
  end 




  # NOTE - Actually does the follow
  def follow(user, do_save = true, mode = :real)
    log(user, "follow")
    return if mode == :preview

    save(@parse_klass, 
          {:handle => user.handle, :mentioned => false, :followed => true, :starred => false}) if do_save == true
    record_hit(:followed, user.handle)

    rate_limit(:follow) { client.follow(user.handle) }
    random_sleep(SLEEP_AFTER_ACTION, 1, SLEEP_AFTER_ACTION_BASE)
  end






  # Search based on an array of given keywords
  # Randomly, tries to find tweets which are only text status (no link)
  # Returns an array of BirdFood
  def search_tweets(keywords, search_operator = "AND", micro_options = {:include_images => true, :exclude_links => false})
    searched_tweets = []
    search_text = keywords.length > 1 ? keywords.join(" #{search_operator} ") : keywords.first
    search_text += " filter:images" if micro_options[:include_images] == true
    search_text += " -http" if micro_options[:exclude_links] == true
    search_text += " -I -am -we -me -my -our"

    log search_text, "Search keywords"

    original_search_count = 0
    rate_limit(:search) {
      search(search_text, {:lang => @config[:lang], :result_type => "recent"}) do |tweet| 
        original_search_count += 1
        #log(tweet, "TWEET")
        searched_tweets << tweet
        break if original_search_count >= @config[:max_count_per_search] # Don't search more than what's requested
      end
    }

    return searched_tweets
  end  




  # TODO - relook into this
  def setup_exclusions(custom_exclude_list = [])
    default_exclusion = ["money", "spammer", "junk", "spam", "fuck", "pussy", "ass", 
                          "shit", "piss", "cunt", "mofo", "cock", "tits", "wife", "sex", "porn",
                          "thanks", "I ", "am", "gun", "wound", "we", "my", "our", "am", "me",
                          "buy", "deal", "follower"]
    @exclude_list = default_exclusion + custom_exclude_list
    exclude(@exclude_list)
  end



  # Figure out which tweet to infest on
  # TODO - how do we check if this is not a dup interaction on the user?
  # mode => :search || :live
  def is_tweet_of_basic_interest?(tweet, mode = :search)
    # If the required lang check is false, don't consider the tweet
    return false if tweet.lang != @config[:lang]

    # Don't process the tweet if we have already infested it before
    return false if check_hit?(:tweet_infested, tweet.id) == true

    # Exclude the tweet if it has lots of hashtags or @ mentions
    return false if tweet.text.count("#") > 3
    return false if tweet.text.count("@") >= 3

    score = 0
    if mode == :search
      score += 1 if tweet.retweet_count >= @config[:tweet][:min_retweet_count] 
      score += 1 if tweet.favorite_count >= @config[:tweet][:min_star_count] 
      return score > 1 ? true : false
    end

    # Only if the tweet has a url AND (is either a via tweet or is not a mention)
    if mode == :live
      # If tweet is not a reply & has no pronouns
      if tweet.reply? == false
        pronouns = [" i ", " i'm ", " am ", ' we ', ' me ', ' my ', 'thank']
        if Regexp.new(pronouns.join("|")).match(tweet.text.downcase) == nil
          #log tweet, "yahoo"
          return true 
        end
      end
      return false
    end

    # default
    return false
  end  




  # Is the tweet like "<foo_text> {via||by} @zoo_user"
  def is_no_mention_or_via_mention_tweet?(tweet)
    return true if tweet.user_mentions? == false

    text = tweet.text.downcase
    via_pos = text.index(" via ") || text.index(" by ") || 10000

    return true if via_pos < (text.index(" @") || 10001)
    return false # default
  end



  # Create enough randomness so that every tweet should not become infestable
  def is_randomly_infestable_tweet?(tweet, divide_by = 2)
    return tweet.id % divide_by == 0 ? true : false
  end



  # If tweet is worthy of a star
  # mode => :search || :live
  def is_starrable?(tweet, mode = :search)
    if mode == :search
      # Min star count
      if tweet.favorite_count >= @config[:tweet][:min_star_count]
        return true
      end
    end

    if mode == :live
      if is_randomly_infestable_tweet?(tweet) == true \
        and is_randomly_infestable_tweet?(tweet) == true
          print "Qs"
          return true
      end
    end      
  
    # default
    return false
  end



  # If tweet is worthy of being retweeted
  # mode => :search || :live
  # keywords => List of keywords needed when mode=:live
  def is_retweetable?(tweet, mode = :search, keywords = [])
    if mode == :search
      # Not a reply, min retweet count, moderate star count
      if ((tweet.favorite_count >= @config[:tweet][:moderate_star_count] \
                and tweet.retweet_count >= @config[:tweet][:min_retweet_count]  \
                and tweet.reply? == false)) \
            or (is_followable?(tweet.user) == true)
        return true
      end
    end

    if mode == :live
      # Should have media and has keywords of interest
      if tweet.media? == true \
          and text_has_keywords?(tweet.text, keywords) == true
          print "Qr"
        return true
      end
    end    

    # default
    return false
  end



  # If tweet is worthy of being clonable (copy=>paste basically)
  # mode => :search || :live
  # keywords => List of keywords needed when mode=:live
  def is_clonable?(tweet, mode = :search, keywords = [])
    if mode == :search
      # Not a reply, Min star count, High retweet count
      if (tweet.favorite_count >= @config[:tweet][:min_star_count] \
            and tweet.retweet_count >= @config[:tweet][:moderate_retweet_count]  \
            and tweet.reply? == false)
        return true
      end
    end

    if mode == :live
      # Should have no media and has keywords of interest
      if tweet.media? == false \
          and text_has_keywords?(tweet.text, keywords) == true
        print "Qc"
        return true
      end
    end

    # default
    return false
  end



  # If the user who tweeted the tweet is followable
  def is_followable?(user, mode = :live)
    return false if user.following? == true

    # Friend to following ratio, stars, tweet count, min followers, since on twitter
    # Should not be following the user already
    followers_count = user.followers_count
    friends_count = user.friends_count
    stars_count = user.favorites_count
    tweets_count = user.tweets_count
    account_age = 0 # TODO

    return false if followers_count > 20*1000  # Anyone with more than 50,000 followers is practically a company/celebrity
    
    followers_to_friends_ratio = (friends_count != 0 ? (followers_count/friends_count).to_f : 0)
    friends_to_followers_ratio = 1/followers_to_friends_ratio.to_f

    return false if friends_to_followers_ratio < 0.2 # Anyone who is not following back is practially a company/celebrity

    if followers_to_friends_ratio >= @config[:user][:followers_to_friends_ratio]  \
        and tweets_count >= @config[:user][:min_tweet_count] \
        and followers_count >= @config[:user][:min_followers_count]  \
        and account_age >= @config[:user][:account_age]
      
      # Only follow if the user is not already being followed
      if check_hit?(:followed, user.handle) == false
        return true
      else
        #puts "Found dup hit in is_followable? @#{user.handle} ================================="
      end        
    end

    return false
  end



  # Returns true if the given text has any of the given keywords
  # keywords => Any sort of array of keywords. Will be flattened, hashes will be removed
  # Atleast min_matching keywords should match, defaults to >1
  def text_has_keywords?(text, keywords, min_matching = 1)
    search_pattern = keywords.flatten.uniq.join("\b|").downcase.gsub("#", "")
    return text.scan(/#{search_pattern}/).uniq.length > 1 ? true : false
  end



  # Given a tweet, find all the hashtags in it
  # Returns => ["a", "b", "c"]
  def hashtags_in_a_tweet(tweet, min_hashtag_length = 4)
    hashtags = []
    tweet.hashtags.each { |hashtag| 
      if hashtag.text.length >= min_hashtag_length
        hashtags << hashtag.text.downcase
      end
    }
    return hashtags.uniq
  end

end