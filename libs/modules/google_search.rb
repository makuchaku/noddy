require 'rubygems'
require 'bundler/setup'

require "google-search"     # used for image search
require "httparty"
require 'htmlentities'


module GoogleSearch

  # search_query => "a b c"
  # returns nil if nothing is found
  def find_google_news(keyword, keyword_suffix, klass = "google_news")
    search_query = "#{keyword} #{keyword_suffix}"
    response = RubyWebSearch::Google.search(:type => :news, :query => search_query, :size => 100)
    response.results.each { |item|
      if check_hit?(klass, item[:url]) == false and item[:language] == 'en'
        record_hit(klass, item[:url])
        return {:item => item, :media_uri => find_media(item[:title])} 
      end
    }

    return nil
  end



  # For a given tweet title, returns the first available google image 
  # returns nil if nothing is found
  def find_google_media(keyword, keyword_suffix, start = 0, klass = "google_image")
    final_keyword = "#{keyword} #{keyword_suffix}"
    puts "Finding image for : #{final_keyword}, cursor_start=#{start}"
    possible_media = GoogleImageSearch.new.search(final_keyword, start)
    return possible_media if possible_media.nil?

    index = 0
    possible_media.each { |media|
      if media[:width] >= 200 and check_hit?(klass, media[:url]) == false
        record_hit(klass, media[:url])
        return media
      end
      index += 1

      # No possible image was found... try going to next page
      if index >= possible_media.length
        return find_google_media(final_keyword, start+8, klass) # TODO : +8 is hardcoded for now, make it cursor based
      end
    }

    return nil
  end  

end






class GoogleImageSearch

  def search(query, start = 0)
    query_options = {} #{:gl => "in"}
    response = HTTParty.get('https://ajax.googleapis.com/ajax/services/search/images', 
                :query => {
                  :v => "1.0", 
                  :q =>  HTMLEntities.new.decode(query), 
                  :start => start, 
                  :rsz => "large", 
                  :hl => "en"
                }.merge(query_options), 
                :headers => {"User-Agent" => "Google Bot", "Referer" => "http://www.google.com"})
    response_json = JSON.parse(response.body)
    if response_json != nil and response_json.keys.index("responseData") != nil
      if response_json["responseData"] != nil and response_json["responseData"]["results"] != nil
        return parse_success_response(response_json)
      end
    end

    return nil
  end


  def parse_success_response(response_json)
    results = []
    objects = response_json["responseData"]["results"]
    objects.each { |object|
      results << {
        :url => object["url"],
        :width => object["width"].to_i,
        :height => object["height"].to_i,
        :titleNoFormatting => object["titleNoFormatting"]
      }
    } 
    puts "Total #{results.length} images found"
    return results
  end

end