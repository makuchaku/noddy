module Toolbox

  SLEEP_GENERIC = 60 # secs
  LOG_FILE_DIRECTORY = "./logs"


  # Helper method to loop
  def self.looper(&block)
    puts "################################################################"
    puts "Starting Looper at #{Time.now}"

    loop do

      begin
        block.call
      rescue Exception => e
        puts "Exception... recovering... : #{e}"
      end

    end

    puts "Ending Looper at #{Time.now}"
    puts "################################################################"    
  end


  # Runs the given block of code in a new thread
  def self.run_in_new_thread(name, &block)
    puts "################################################################"
    puts "Pre Thread #{name} at #{Time.now}"

    # Don't wait for it to finish
    thread = Thread.start do
      block.call
    end

    puts "Post Thread #{name} at #{Time.now}"
    puts "################################################################"   

    return thread 
  end



  # threads => [thread_obj_1, ...]
  # Ensures that till threads are not killed, main thread will not exit
  def self.wait_for_threads(threads)
    threads.each { |thread| thread.join }
  end



  # Calls the given block with a sleeping factor of the rate limiting
  # Currently we don't care about the lost activity as we don't redo
  def rate_limit(where, &block)
    # does nothing as of now
  end  


  # Generic logging
  def log(object, prefix="log")
    puts "[#{prefix.upcase}] #{object}"
  end


  # Min base will be added to all random sleeps
  def random_sleep(how_much = SLEEP_GENERIC, multiplier = 1, min_base = 0)
    sleep_for = rand(how_much * multiplier) + min_base
    puts "Sleeping for a random #{sleep_for} seconds\n"
    sleep(sleep_for)
  end


  # Executes the given block after random time in a new thread
  def do_later(random_sleep_max_time = SLEEP_GENERIC, multiplier = 1, min_base = 0, &block)
    Thread.start do
      random_sleep(random_sleep_max_time, multiplier, min_base)
      block.call
    end
  end



  # klass => a particular name for the logfile
  def record_hit(klass, data)
    system("echo '#{data}' >> #{get_log_file_name(klass)}")
  end



  def get_log_file_name(klass)
    #system("mkdir -p #{LOG_FILE_DIRECTORY}")
    return "#{LOG_FILE_DIRECTORY}/#{klass.to_s}.txt"
  end



  # returns true if data was found for the klass
  def check_hit?(klass, data, verbosity=:silent)
    sleep 0.1 # Prevent system abuse
    print "."
    command = "grep '#{data}' #{get_log_file_name(klass)} 1>/dev/null"
    result = system(command)
    puts "check_hit? was #{result} for #{klass}" if verbosity == :verbose
    return result
  end


  # Download a web url to disk
  def download_url(url, output_filename, dir_name = "media/tmp")
    command = "wget --quiet '#{url}' -O '#{dir_name}/#{output_filename}'"
    system(command)
  end


  # For a given base, return base+rand(x)
  def with_x_percentage_additional_random(base, x_percentage)
    random_x_percentage = rand(x_percentage)
    return (base + (random_x_percentage*base/100)).to_i
  end

end