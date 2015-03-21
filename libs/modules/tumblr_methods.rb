require 'rubygems'
require 'bundler/setup'
require "tumblr_client"

module TumblrMethods

  def get_tumblr_client(auth)
    # Authenticate via OAuth
    return client = Tumblr::Client.new(auth)
  end


end