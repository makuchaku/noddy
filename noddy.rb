require "./libs/toolbox"
require "./libs/parse_methods"
require "./libs/google_search"
require "./libs/string_methods"
require "./libs/tumblr_methods"


class Noddy

  include Toolbox
  include GoogleSearch
  include StringMethods
  include ParseMethods
  include TumblrMethods

  attr_accessor :tumblr


  def initialize(options)
    @options = options
    @auth = @options[:auth]
    @blog = @options[:blog]
    @keywords = @options[:keywords]
    @keyword_suffix = @options[:keyword_suffix]

    setup_tumblr
  end


  def setup_tumblr
    @tumblr = get_tumblr_client(@auth)
  end


  # Returns the newly created thread
  def threaded_looped_generate_posts
    return Toolbox::run_in_new_thread "#{__method__}" do
      Toolbox::looper do
        log "--------------------------------------------"
        generate_photo_post(@keywords.sample, @keyword_suffix)
        random_sleep
        log "--------------------------------------------"
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





  # Generates a photo post, given a keyword and keyword_suffix
  def generate_photo_post(keyword, keyword_suffix)
    klass = @blog + "_google_media"
    image = find_google_media(keyword, keyword_suffix, rand(10)*8, klass) # try to start media search from a random page number
  
    if image != nil
      log "Creating a photo post with image : #{image[:url]}" 

      @tumblr.photo(@blog, {
          :source => image[:url],
          :link => "http://j.mp/1O4ohxR",
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






