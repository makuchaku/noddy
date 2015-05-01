require 'rubygems'
require 'bundler/setup'

# Modules
require "./libs/modules/toolbox"
require "./libs/modules/parse_methods"
require "./libs/modules/google_search"
require "./libs/modules/string_methods"

# Classes
require "./libs/classes/twitter_for_noddy"
require "./libs/classes/tumblr_for_noddy"
require "./libs/classes/similar_keywords"


class Noddy

  attr_accessor :tumblr, :twitter


  def initialize(options)
    @options = options

    @twitter = TwitterForNoddy.new(@options[:twitter_config])
    @tumblr = TumblrForNoddy.new(@options)
  end




  # Launches entire set of methods to run noddy
  def launch_tumblr_for_noddy(config = {:generate_posts => true, :generate_follow => true, :generate_keywords => true})
    threads = []
    threads << @tumblr.threaded_looped_generate_posts if config[:generate_posts] == true
    threads << @tumblr.threaded_looped_follow_blogs if config[:generate_follow] == true
    threads << @tumblr.threaded_looped_generate_keywords if config[:generate_keywords] == true
    Toolbox::wait_for_threads(threads)
  end



end






