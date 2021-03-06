require "tumblr_client"
require "./libs/modules/toolbox.rb"

class TumblrForNoddy

  include Toolbox
  include GoogleSearch
  include StringMethods
  include ParseMethods


  def initialize(options)
    @options = options
    @tumblr_auth = @options[:tumblr_auth]
    @twitter_config = @options[:twitter_config]
    @blog = @options[:blog]
    @original_keywords = @options[:keywords]
    @keywords = @options[:keywords]
    @keyword_suffix = @options[:keyword_suffix]

    @tumblr = get_tumblr_client(@tumblr_auth)
    @twitter = TwitterForNoddy.new(@options[:twitter_config])
  end


  def get_tumblr_client(tumblr_auth)
    # Authenticate via OAuth
    return client = Tumblr::Client.new(tumblr_auth)
  end


  # Returns the newly created thread
  def threaded_looped_generate_posts
    return Toolbox::run_in_new_thread "#{__method__}" do
      Toolbox::looper do
        log "----------------------threaded_looped_generate_posts----------------------"
        generate_photo_post(@keywords.sample, @keyword_suffix)
        random_sleep
        log "----------------------threaded_looped_generate_posts----------------------"
      end
    end # run_in_new_thread
  end



  # Returns the newly created thread
  def threaded_looped_follow_blogs
    return Toolbox::run_in_new_thread "#{__method__}" do
      Toolbox::looper do
        log "--------------------------------------------"
        potential_blogs_to_follow = find_blogs_to_follow(@keywords.sample, {:limit => 5})
        follow_many_blogs(potential_blogs_to_follow)
        random_sleep
        log "--------------------------------------------"
      end
    end # run_in_new_thread
  end




  # Returns the newly created thread
  def threaded_looped_generate_keywords
    return Toolbox::run_in_new_thread "#{__method__}" do
      Toolbox::looper do
        s = SimilarKeywords.new({:twitter => @twitter, :max_recursive_depth => 0})
        new_keywords = s.find_more_keywords_like([@keywords.sample]).get_keywords
        @keywords << new_keywords
        log "Adding #{new_keywords} to @keywords", :threaded_looped_generate_keywords
        @keywords.flatten!
        @keywords.uniq!
        log "@keywords = #{@keywords}", :threaded_looped_generate_keywords
        random_sleep(60)
      end # looper
    end # run_in_new_thread
  end




  # Generates a photo post, given a keyword and keyword_suffix
  def generate_photo_post(keyword, keyword_suffix)
    klass = @blog + "_google_media"
    image = find_google_media(keyword, keyword_suffix, rand(10)*8, klass) # try to start media search from a random page number
    
    # Remove from the @keywords if the given keyword is not one of the original keyword
    @keywords.delete(keyword) if @original_keywords.index(keyword) != nil

    if image != nil
      log "Creating a photo post with image : #{image[:url]}" 

      @tumblr.photo(@blog, {
          :source => image[:url],
          :link => "http://j.mp/1DXwSKd",
          :caption => image[:titleNoFormatting],
          :tags => sentence_to_tags(keyword)
        })
    else
      log "No image found, next..."
    end
  end




  # Given a keyword, find users to follow
  def find_blogs_to_follow(keyword, options = {:limit => 20})
    klass = @blog + "_users_to_follow"
    potential_blogs_to_follow = []

    log "Finding posts for #{keyword}"
    posts = @tumblr.tagged(keyword, options)

    posts.each { |post|
      if post["followed"] == false
        if check_hit?(klass, post["blog_name"]) == false
          record_hit(klass, post["blog_name"])
          potential_blogs_to_follow << post["blog_name"]
        end
      end
    }

    return potential_blogs_to_follow
  end




  # Follows many blogs
  def follow_many_blogs(blogs)
    blogs.each { |blog|
      follow_blog(blog)
      random_sleep
    }
  end



  # Follows a blog
  def follow_blog(blog)
    blog = "#{blog}.tumblr.com"
    log "Following blog : #{blog}"
    @tumblr.follow(blog)    
  end


end