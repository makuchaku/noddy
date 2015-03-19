# All methods which are required to work with Parse
module ParseMethods


  def init_parse_auth(auth)
    Parse.init :application_id => auth[:application_id],
               :api_key        => auth[:api_key]  
  end


  # klass => The class name
  # params => {k1=>v1, k2=>v2}
  # params[:primary_key] is an expected key for now - OR the object would be created as new
  # First searches for a unique reference of params[:primary_key] and then either updates the found object or creates new
  def parse_save(klass, params)
    puts "Saving in Parse [#{klass}] : #{params.to_json}"

    raise if params[:primary_key] == nil
    
    obj = find(klass, {
            :find_by_key => "primary_key", # primary_key is the primary key for all save operations
            :find_by_value => params[:primary_key], 
            :limit => 1
          }).first

    obj = obj || Parse::Object.new(klass)
    params.each { |key, value|
      obj[key.to_s] = value
    }
    obj.save
    return obj
  end


  # klass => The class name
  # params => {:find_by_key=>"mentioned", :find_by_value=>true, :order_by_key=>"createdAt", :sort=>:descending, :limit=>1}
  def parse_find(klass, config)
    objects = Parse::Query.new(klass).tap do |q|
      q.eq(config[:find_by_key], config[:find_by_value])
      q.order_by = config[:order_by_key]
      q.order    = config[:sort]
      q.limit    = config[:limit].to_i
    end.get

    return objects
  end

end

