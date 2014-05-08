require "time"
require "stringio"

# IMPORTANT! Requiring Rubygems is NOT a best practice. See http://scoutapp.com/info/creating_a_plugin#libraries
# This plugin is an exception because we need to modify the Elif library (both here and below) before the plugin's build_report method is run.
require 'rubygems'
require 'elif'
Elif.send(:remove_const, :MAX_READ_SIZE); Elif::MAX_READ_SIZE = 1024*100

class RailsRequests < Scout::Plugin
  ONE_DAY    = 60 * 60 * 24
  # prior versions of request log analyzer have a different API. 
  OLDER_RLA_VERSION = Gem::Version.new("1.3.7")

  OPTIONS=<<-EOS
  log:
    name: Full Path to Rails Log File
    notes: "The full path to the Ruby on Rails log file you wish to analyze (ex: /var/www/apps/APP_NAME/current/log/production.log)."
  max_request_length:
    name: Max Request Length (sec)
    notes: If any request length is larger than this amount, an alert is generated (see Advanced for more options)
    default: 3
  max_memory_diff:
    name: Max Memory Difference (MB)
    notes: If any request results in a change in memory larger than this amount, an alert is generated. The Oink plugin must be installed in your Rails application.
    default: 50
    attributes: advanced
  rla_run_time:
    name: Request Log Analyzer Run Time (HH:MM)
    notes: It's best to schedule these summaries about fifteen minutes before any logrotate cron job you have set would kick in. The time should be in the server timezone.
    default: '23:45'
    attributes: advanced
  ignored_actions:
    name: Ignored Actions
    notes: Takes a regex. Any URIs matching this regex will NOT count as slow requests, and you will NOT be notified if they exceed Max Request Length. Matching actions will still be included in daily summaries.
    attributes: advanced
  rails_version:
    notes: "The version of Ruby on Rails used for this application (examples: 2, 2.2, 3, 4). If none is provided, defaults to 4."
  EOS

  needs "request_log_analyzer"
  def build_report
    patch_elif
    # RLA 1.11.0 offers a memory-safe version of gets for Ruby >= 1.9 but not for previous Rubies. 
    # This is eval'd if < RLA 1.11.0 or Ruby < 1.9.
    self.class.class_eval(FILE_EXTS) if Gem::Version.new(RequestLogAnalyzer::VERSION) < Gem::Version.new("1.11.0") or RUBY_VERSION.to_f < 1.9

    @log_path = option(:log)
    
    @file_found = file_readable?(@log_path)
    return if !@file_found
    
    @max_length = option(:max_request_length).to_f
    @max_memory_diff = option(:max_memory_diff) ? option(:max_memory_diff).to_f : nil
    
    init_ignored_actions # sets @ignored_actions@
    init_parser # sets @file_format    
    init_tracking # data the plugin tracks
    init_file_pointer # sets @previous_position
    init_previous_last_request_time # sets @previous_last_request_time, @previous_last_request_time_as_timestamp
    
    test_parsing if option(:log_test) # parses a big chunk of the log file if true (ignores previous position)

    # set to the time of the last request processed. the next run will start parsing requests later requests.
    last_request_time  = nil
    
    # for dev debugging
    skipped_requests_count = 0
    
    File.open(@log_path, 'rb') do |f| 
      # seek to the last position in the log file
      f.seek(@previous_position, IO::SEEK_SET)      
      # use the log parser to build requests from the lines.
      @log_parser.parse_io(f) do |request|
        # store the last file position and timestamp of the last request processed.
        last_request_time = request[:timestamp]
        # don't process requests if they are before the last request processed.
        if request[:timestamp] <= @previous_last_request_time_as_timestamp
          skipped_requests_count += 1
        else
          @total_request_count += 1 
          completed_line = request.has_line_type?(:completed)
          next if completed_line.nil? # request could be a failure. if so, no metrics to parse.
          parse_request(request)
        end
        
      end # parse_io
    
    end # File.open
    
    generate_slow_request_alerts
    generate_memory_leak_alerts
    
    remember(:last_request_time, last_request_time ? Time.parse(last_request_time.to_s) : Time.now)

    report(aggregate)
  rescue Exception => e
    error("#{e.class}:  #{e.message}", e.backtrace.join("\n"))
  ensure
    # only run the analyzer if the log file is provided
    # this may take a couple of minutes on large log files.
    if @file_found and option(:log) and not option(:log).empty?
      generate_log_analysis(@log_path)
    end
  end
  
  private
  
  # Ensure (a) a file path is provided (b) exists (c) is readable. Generates an error and returns +false+ if if the file isn't readable, otherwise +true+.
  def file_readable?(path)
    unless path and not path.empty?
      error("A path to the Rails log file wasn't provided.","Please provide the full path to the Rails log file to analyze (ie - /var/www/apps/APP_NAME/log/production.log)")      
      return false
    end
    # File#exist? returns false if the file exists but isn't readable. This provides a more accurate error message.
    begin 
      FileTest.size(path)
    rescue Errno::EACCES
      error("The Rails log file isn't readable", "The log file at #{path} isn't readable by the user running Scout. Please update the file permissions to give the user access.")
    rescue Errno::ENOENT
      error("Unable to find the Rails log file", "Could not find a Rails log file at: #{path}. Please ensure the path is correct.")
    rescue
      error("Unable to read the Rails log file", "The log file at: #{path} couldn't be accessed (#{$!.message}).")
    end
    data_for_server[:errors].any? ? false : true
  end

  # Process the ignored_actions option -- this is a regex provided by users; matching URIs don't get counted as slow.
  # Actions are stored in +@ignored_actions+. If the RegEx cannot be generated, an Argument Error is created.
  def init_ignored_actions
    @ignored_actions=nil
    if option(:ignored_actions) && option(:ignored_actions).strip != ''
      begin
        @ignored_actions = Regexp.new(option(:ignored_actions))
      rescue
        error("Argument error","Could not understand the regular expression for excluding slow actions: #{option(:ignored_actions)}. #{$!.message}")
      end
    end
  end
  
  # Set the RLA rails format to +@file_format+ and inits the log parser (@log_parser). If none provided, defaults to Oink (which is v2).
  def init_parser
    set_file_format_class
    # will use minimal line collection for incremental parsing. using more line collections increases
    # parsing time. 
    if @file_format_class == RequestLogAnalyzer::FileFormat::Rails or @file_format_class.superclass == RequestLogAnalyzer::FileFormat::Rails
      @file_format = @file_format_class.create('minimal')  
    else # Rails3 doesn't have option of minimal processing
      @file_format = @file_format_class.create
    end
    @log_parser  = RequestLogAnalyzer::Source::LogParser.new(@file_format)
  end
  
  # Need the class for incremental parsing and the daily report. 
  # Incremental uses a minimal parsing strategy for performance - the daily report does not.
  def set_file_format_class
    rails_version = option(:rails_version)
    rails_version = rails_version.to_s[0..0].to_i
    @file_format_class = case rails_version
              when 2
                RequestLogAnalyzer::FileFormat::Oink
              when 3
                # TODO - Add Oink processing for Rails3 files
                RequestLogAnalyzer::FileFormat::Rails3
              when 4
                RequestLogAnalyzer::FileFormat::Rails3
              else
                RequestLogAnalyzer::FileFormat::Rails3
              end
  rescue LoadError # Oink format not available on RLA < 1.8
    @file_format_class = RequestLogAnalyzer::FileFormat::Rails
  end
  
  # Inits data the plugin tracks, ie slow request count, slow requests, etc
  def init_tracking
    @slow_request_count     = 0
    @total_request_count    = 0 # includes requests that don't have duration info
    @request_count          = 0
    @last_completed         = nil
    @slow_requests          = ''
    @leaking_requests_count = 0
    @leaking_requests       = ''
    @total_request_time     = 0.0
    @total_view_time        = 0.0
    @total_db_time          = 0.0
  end
  
  # seeks to the previous file pointer position in the log file. saves the new previous position for the 
  # next run.
  # - if no previous position exists, sets the file pointer to the end of the file - MAX_READ_SIZE
  # - for logrotate, if the previous position is greater than the current one, sets the position to 0
  #   to start with the fresh file.
  def init_file_pointer
    @previous_position  = memory(:previous_position)
    current_position    = `wc -c #{@log_path}`.split(' ')[0].to_i
    remember(:previous_position,current_position)
    if @previous_position and current_position < @previous_position
      # log file rotated - set position to zero
      @previous_position = 0
    elsif @previous_position.nil?
      # first run
      @previous_position = current_position - File::MAX_READ_SIZE
      @previous_position < 0 ? @previous_position = 0 : nil
    end    
  end
  
  # sets @previous_last_request_time, @previous_last_request_time_as_timestamp
  def init_previous_last_request_time    
    @previous_last_request_time = memory(:last_request_time) || Time.now-60 # analyze last minute on first invocation
    # Time#parse is slow so uses a specially-formatted integer to compare request times.
    @previous_last_request_time_as_timestamp = @previous_last_request_time.strftime('%Y%m%d%H%M%S').to_i
  end
  
  # Calculates data to report 
  def aggregate
    report_data        = { :slow_request_rate      => 0,
                           :request_rate           => 0,
                           :average_request_length => nil,
                           :average_db_time        => nil,
                           :average_view_time      => nil }
  
    # Calculate the average request time and request rate if there are any requests
    if @request_count > 0
     interval = set_interval
     # determine the rate of requests and slow requests in requests/min
     report_data[:request_rate]           = average(@total_request_count,interval)
     report_data[:slow_request_rate]      = average(@slow_request_count,interval)

     # determine the average times for the whole request, db, and view
     report_data[:average_request_length] = average(@total_request_time,@request_count)
     report_data[:average_db_time]        = average(@total_db_time,@request_count)
     report_data[:average_view_time]      = average(@total_view_time,@request_count)

     report_data[:slow_requests_percentage] = (@request_count == 0) ? 0 : (@slow_request_count.to_f / @request_count.to_f) * 100.0
    end
    return report_data
  end
  
  # Given a total and a count, returns a string-formatted average 
  def average(total,count)
    avg = total/count
    sprintf("%.2f", avg)
  end
  
  # calculate the time btw runs in minutes
  # this is used to generate rates.
  def set_interval
    interval = (Time.now-(@last_run || @previous_last_request_time))

    interval < 1 ? interval = 1 : nil # if the interval is less than 1 second (may happen on initial run) set to 1 second
    interval = interval/60 # convert to minutes
    interval = interval.to_f
  end
  
  # Will parse a big chunk of the log file when these are set. This method if called if
  # option(:log_test) = true.
  def test_parsing
    @previous_position          = 0
    @previous_last_request_time = Time.now-(60*60*24*300)
    @previous_last_request_time_as_timestamp = @previous_last_request_time.strftime('%Y%m%d%H%M%S').to_i
  end
  
  def parse_request(request) 
    @request_count += 1
    url= request[:url] || request[:path]
    
    parse_timing(request,url)
    parse_memory(request,url)
  end
  
  def parse_timing(request,url)
    @total_request_time     += request[:duration]
    @total_view_time        += (request[:view] || 0.0)
    @total_db_time          += (request[:db] || 0.0) 
    if @max_length > 0 and request[:duration] > @max_length
      # url is in :completed in rails2; path is in :started in rails3
      # only test for ignored_actions if we actually have an ignored_actions regex
      if @ignored_actions.nil? || (@ignored_actions.is_a?(Regexp) && !@ignored_actions.match(url))
        @slow_request_count += 1         
        slow_request_string = "#{url[0..200]}\nCompleted in #{request[:duration]}s"
        if request[:view] and request[:db]
          slow_request_string << " (View: #{request[:view]}s, DB: #{request[:db]}s)"
        end     
        slow_request_string << " | Status: #{request[:status]}\n\n"
        @slow_requests += slow_request_string
      end
    end
  end
  
  def parse_memory(request,url)
    # memory_diff is in bytes ... max_memory_diff in MB
    if @max_memory_diff and diff=request[:memory_diff] and diff > @max_memory_diff*1024*1024
      @leaking_requests_count +=1
      @leaking_requests += "#{url}\nMemory Increase: #{diff / 1024 / 1024} MB | Status: #{request[:status]}\n\n"
    end 
  end
  
  def generate_slow_request_alerts
    # Create a single alert that holds all of the requests that exceeded the +max_request_length+.
    if (count = @slow_request_count) > 0
      alert( "Maximum Time(#{option(:max_request_length)} sec) exceeded on #{count} request#{'s' if count != 1}",
             @slow_requests )
    end
  end
  
  def generate_memory_leak_alerts
    # Create a single alert that holds all of the requests that exceeded the +max_memory_diff+.
    if (count = @leaking_requests_count) > 0
      alert( "Maximum Memory Increase(#{@max_memory_diff} MB) exceeded on #{count} request#{'s' if count != 1}",
             @leaking_requests )
    end
  end

  # Time.parse is slow...uses this to compare times.
  def convert_timestamp(value)
    value.gsub(/[^0-9]/, '')[0...14].to_i
  end
  
  def silence
    old_verbose, $VERBOSE, $stdout = $VERBOSE, nil, StringIO.new
    yield
  ensure
    $VERBOSE, $stdout = old_verbose, STDOUT
  end
  
  def generate_log_analysis(log_path)
    # decide if it's time to run the analysis yet today
    if option(:rla_run_time) =~ /\A\s*(0?\d|1\d|2[0-3]):(0?\d|[1-4]\d|5[0-9])\s*\z/
      run_hour    = $1.to_i
      run_minutes = $2.to_i
    else
      run_hour    = 23
      run_minutes = 45
    end
    now = Time.now
    if last_summary = memory(:last_summary_time)
      if now.hour > run_hour       or
        ( now.hour == run_hour     and
          now.min  >= run_minutes ) and
         %w[year mon day].any? { |t| last_summary.send(t) != now.send(t) }
        remember(:last_summary_time, now)
      else
        remember(:last_summary_time, last_summary)
        return
      end
    else # summary hasn't been run yet ... set last summary time to 1 day ago
      last_summary = now - ONE_DAY
      # remember(:last_summary_time, last_summary)
      # on initial run, save the last summary time as now. otherwise if an error occurs, the 
      # plugin will attempt to create a summary on each run.
      remember(:last_summary_time, now) 
    end
    # make sure we get a full run
    if now - last_summary < 60 * 60 * 22
      last_summary = now - ONE_DAY
    end
    
    self.class.class_eval(RLA_EXTS)
    
    analysis = analyze(last_summary, now, log_path)
    summary( :command => "request-log-analyzer --after '"                   +
                         last_summary.strftime('%Y-%m-%d %H:%M:%S')         +
                         "' --before '" + now.strftime('%Y-%m-%d %H:%M:%S') +
                         "' '#{log_path}'",
             :output  => analysis )
  rescue Exception => error
    error("#{error.class}:  #{error.message}", error.backtrace.join("\n"))
  end
  
  def analyze(last_summary, stop_time, log_path)
    log_file = read_backwards_to_timestamp(log_path, last_summary)
    if Gem::Version.new(RequestLogAnalyzer::VERSION) <= OLDER_RLA_VERSION
      analyzer_with_older_rla(last_summary, stop_time, log_file)
    else
      analyzer_with_newer_rla(last_summary, stop_time, log_file)
    end
  end
  
  def analyzer_with_older_rla(last_summary, stop_time, log_file)
    summary  = StringIO.new
    output   = EmbeddedHTML.new(summary)
    options  = {:source_files => log_file, :output => output}
    source   = RequestLogAnalyzer::Source::LogParser.new(@file_format_class, options)
    control  = RequestLogAnalyzer::Controller.new(source, options)
    control.add_filter(:timespan, :after  => last_summary)
    control.add_filter(:timespan, :before => stop_time)
    control.add_aggregator(:summarizer)
    source.progress = nil
    @format.setup_environment(control)
    silence do
      control.run!
    end
    summary.string.strip
  end
  
  def analyzer_with_newer_rla(last_summary, stop_time, log_file)
    summary = StringIO.new
    RequestLogAnalyzer::Controller.build(
      :output       => EmbeddedHTML,
      :file         => summary,
      :after        => last_summary, 
      :before       => stop_time,
      :source_files => log_file,
      :format       => @file_format_class
    ).run!
    summary.string.strip
  end
  
  def patch_elif
    if Elif::VERSION < "0.2.0"
      Elif.send(:define_method, :pos) do
        @current_pos +
        @line_buffer.inject(0) { |bytes, line| bytes + line.size }
      end
    end
  end
  
  def read_backwards_to_timestamp(path, timestamp)
    start = nil
    Elif.open(path) do |elif|
      elif.each do |line|
        if line =~ /\AProcessing .+ at (\d+-\d+-\d+ \d+:\d+:\d+)\)/
          time_of_request = Time.parse($1)
          if time_of_request < timestamp
            break
          else
            start = elif.pos
          end
        end
      end
    end

    file = open(path)
    file.seek(start) if start
    file
  end
  
  # RLA 1.11.0 offers a memory-safe version of gets for Ruby >= 1.9 but not for previous Rubies. 
  # This is eval'd if < RLA 1.11.0 or Ruby < 1.9.
  FILE_EXTS = <<-'END_FILE_EXTS'
  class ::File
    alias_method :gets, :gets_memory_safe
  end
  END_FILE_EXTS
  
  RLA_EXTS = <<-'END_RUBY'
  class EmbeddedHTML < RequestLogAnalyzer::Output::Base
    def print(str)
      @io << str
    end
    alias_method :<<, :print
    
    def colorize(text, *style)
      if style.include?(:bold)
        tag(:strong, text)
      else
        text
      end
    end
  
    def puts(str = "")
      @io << "#{str}<br/>\n"
    end
  
    def title(title)
      @io.puts(tag(:h2, title))
    end
  
    def line(*font)  
      @io.puts(tag(:hr))
    end
  
    def link(text, url = nil)
      url = text if url.nil?
      tag(:a, text, :href => url)
    end
  
    def table(*columns, &block)
      rows = Array.new
      yield(rows)
  
      @io << tag(:table, :cellspacing => 0) do |content|
        if table_has_header?(columns)
          content << tag(:tr) do
            columns.map { |col| tag(:th, col[:title]) }.join("\n")
          end
        end
  
        odd = false
        rows.each do |row|
          odd = !odd
          content << tag(:tr) do
            if odd
              row.map { |cell| tag(:td, cell, :class => "alt") }.join("\n") 
            else
              row.map { |cell| tag(:td, cell) }.join("\n") 
            end
          end
        end
      end
    end
  
    def header
    end
  
    def footer
      @io << tag(:hr) << tag(:p, "Powered by request-log-analyzer v#{RequestLogAnalyzer::VERSION}")
    end
  
    private
  
    def tag(tag, content = nil, attributes = nil)
      if block_given?
        attributes = content.nil? ? "" : " " + content.map { |(key, value)| "#{key}=\"#{value}\"" }.join(" ")
        content_string = ""
        content = yield(content_string)
        content = content_string unless content_string.empty? 
        "<#{tag}#{attributes}>#{content}</#{tag}>"
      else
        attributes = attributes.nil? ? "" : " " + attributes.map { |(key, value)| "#{key}=\"#{value}\"" }.join(" ")
        if content.nil?
          "<#{tag}#{attributes} />"
        else
          if content.class == Float
            "<#{tag}#{attributes}><div class='color_bar' style=\"width:#{(content*200).floor}px;\"/></#{tag}>"
          else
            "<#{tag}#{attributes}>#{content}</#{tag}>"
          end
        end
      end
    end  
  end
  END_RUBY
end

### Modifications below for Elif and File to ignore large chunks of data in long lines.
$VERBOSE=nil # prevent method overwrite warnings
class Elif
  # This is a modified version of +gets+. It ignores any segments that do not contain the 
  # +sep_string+. This prevents the buffer from growing in size in using more memory.
  def gets(sep_string = $\)
    # 
    # If we have more than one line in the buffer or we have reached the
    # beginning of the file, send the last line in the buffer to the caller.  
    # (This may be +nil+, if the buffer has been exhausted.)
    # 
    return @line_buffer.pop if @line_buffer.size > 2 or @current_pos <= 0
        
    # 
    # Read more bytes and prepend them to the first (likely partial) line in the
    # buffer.
    # 
    chunk = String.new
    # read from the file and exit when a segment is read that contains the +set_string+.
    while chunk and chunk !~ /#{sep_string}/ and @current_pos > 0   
      # 
      # If we made it this far, we need to read more data to try and find the 
      # beginning of a line or the beginning of the file.  Move the file pointer
      # back a step, to give us new bytes to read.
      #
      @current_pos -= @read_size
      if @current_pos >= 0
        @file.seek(@current_pos, IO::SEEK_SET) 
        chunk = @file.read(@read_size)
      end
    end
    
    @line_buffer[0] = "#{chunk}#{@line_buffer[0]}"

    @read_size      = MAX_READ_SIZE  # Set a size for the next read.
    
    # 
    # Divide the first line of the buffer based on +sep_string+ and #flatten!
    # those new lines into the buffer.
    # 
    @line_buffer[0] = @line_buffer[0].scan(/.*?#{Regexp.escape(sep_string)}|.+/)
    @line_buffer.flatten!
    
    # We have move data now, so try again to read a line...
    gets(sep_string)
  end
end

class File
  # The size of the reads we will use to add to the line buffer.
  MAX_READ_SIZE=1024*100 unless const_defined?(:MAX_READ_SIZE)
  
  # 
  # This method returns the next line of the File.
  # 
  # It works by moving the file pointer forward +MAX_READ_SIZE+ at a time, 
  # storing seen lines in <tt>@line_buffer</tt>.  Once the buffer contains at 
  # least two lines (ensuring we have seen on full line) or the file pointer 
  # reaches the end of the File, the last line from the buffer is returned.  
  # When the buffer is exhausted, this will throw +nil+ (from the empty Array).
  #
  # Read portions of the file that do not contain the +sep_string+ are not added to 
  # the buffer. This prevents <tt>@line_buffer<tt> from growing signficantly when parsing
  # large lines.
  #
  def gets_memory_safe(sep_string = $/, max_line_length=8096)
    @read_size ||= MAX_READ_SIZE
    # A buffer to hold lines read, but not yet returned.
    @line_buffer ||= Array.new
        
    # Record where we are.
    @current_pos ||= pos
        
    # Last Position in the file
    @last_pos ||= nil
    if @last_pos.nil? 
      seek(0, IO::SEEK_END)
      @last_pos = pos
      seek(@current_pos,IO::SEEK_SET) # back to the original position
    end
    
    # 
    # If we have more than one line in the buffer or we have reached the
    # beginning of the file, send the last line in the buffer to the caller.  
    # (This may be +nil+, if the buffer has been exhausted.)
    #
    if @line_buffer.size > 2 or @current_pos >= @last_pos
      self.lineno += 1
      return @line_buffer.shift 
    end
        
    chunk = String.new
    while chunk and chunk !~ /#{sep_string}/   
      chunk = read(@read_size)
    end
    
    # Appends new lines to the last element of the buffer
    line_buffer_pos = @line_buffer.any? ? @line_buffer.size-1 : 0
    
    if chunk
      @line_buffer[line_buffer_pos] = @line_buffer[line_buffer_pos].to_s<< chunk
    else
      # at the end
      return @line_buffer.shift
    end
    
    # 
    # Divide the last line of the buffer based on +sep_string+ and #flatten!
    # those new lines into the buffer.
    # 
    @line_buffer[line_buffer_pos] = @line_buffer[line_buffer_pos].scan(/.*?#{Regexp.escape(sep_string)}|.+/)
    @line_buffer.flatten!

    # 
    # If we made it this far, we need to read more data to try and find the 
    # end of a line or the end of the file.  Move the file pointer
    # forward a step, to give us new bytes to read.
    #
    @current_pos += @read_size
    seek(@current_pos, IO::SEEK_SET)
    
    # We have more data now, so try again to read a line...
    gets(sep_string)
  end  
end