require "time"
require "stringio"

class ApacheAnalyzer < Scout::Plugin
  ONE_DAY                   = 60 * 60 * 24
  ESCAPED_PEFORMANCE_FORMAT = '%h %l %u %t \"%r\" %>s %b %D'
  PERFORMACE_FORMAT         = '%h %l %u %t "%r" %>s %b %D'
  
  OPTIONS=<<-EOS
  log:
    name: Full Path to Apache Log File
    notes: "The full path to the Apache log file you wish to analyze (ex: /var/www/apps/APP_NAME/current/log/access_log)."
  format:
    name: Apache Log format
    notes: defaults to 'common'. Or specify custom log format, like %h %l %u %t "%r" %>s %b %D
    default: common
  rla_run_time:
    name: Request Log Analyzer Run Time (HH:MM)
    notes: It's best to schedule these summaries about fifteen minutes before any logrotate cron job you have set would kick in. The time should be in the server timezone.
    default: '23:45'
  ignored_paths:
    name: Ignored Paths
    notes: Takes a regex. Any URIs matching this regex will be ignored. Matching paths will still be included in daily summaries.
    attributes: advanced
  EOS

  needs "elif"
  needs "request_log_analyzer"

  def build_report
    patch_elif

    log_path                   = option(:log)
    format                     = scan_format
    
    unless log_path and not log_path.empty?
      return error("A path to the Apache log file wasn't provided.","Please provide the full path to the Apache log file to analyze (ie - /etc/httpd/logs/access.log)")
    end
    unless File.exist?(log_path)
      return error("Unable to find the Apache log file", "Could not find an Apache log file at: #{option(:log)}. Please ensure the path is correct.")
    end
    
    @ignored_paths=nil
    if option(:ignored_paths)
      begin
        @ignored_paths = Regexp.new(option(:ignored_paths))
      rescue
        error("Argument error","Could not understand the regular expression for ignored paths: #{option(:ignored_paths)}. #{$!.message}")
      end
    end

    init_tracking
    init_timing
    
    # build the line definition and request using RLA. we'll use this to parse each line.
    @line_definition = RequestLogAnalyzer::FileFormat::Apache.access_line_definition(format)
    @request         = RequestLogAnalyzer::FileFormat::Apache.new.request
        
    # read backward, counting lines
    Elif.foreach(log_path) do |line|
      @lines_scanned += 1
      break if parse_line(line).nil?
    end

    remember(:last_request_time, @last_request_time || Time.now)
    report(aggregate)
    if log_path && !log_path.empty?
      generate_log_analysis(log_path, format)
    else
      return error("A path to the Apache log file wasn't provided.","Please provide the full path to the Apache log file to analyze (ie - /var/www/apps/APP_NAME/log/access_log)")
    end
  end
  
  def scan_format
    if option(:format).nil?
      'common'
    # handles common error in options - escaping "r", but Scout passes format down in single quotes.
    elsif option(:format) == ESCAPED_PEFORMANCE_FORMAT
      PERFORMACE_FORMAT
    else
      option(:format)
    end
  end

  private
  
  # Calculates the request rate, number of lines scanned, and average request time (if possible)
  def aggregate
    report_data = { :request_rate => 0, :lines_scanned => 0 }
    
    report_data[:lines_scanned] = @lines_scanned

    # calculate request_rate and average request time if any requests were found
    if @request_count > 0
      # calculate the time btw runs in minutes
      interval = (Time.now-(@last_run || @previous_last_request_time))
      interval < 1 ? interval = 1 : nil # if the interval is less than 1 second (may happen on initial run) set to 1 second
      interval = interval/60 # convert to minutes
      interval = interval.to_f
      # determine the rate of requests and slow requests in requests/min
      report_data[:request_rate]             = average(@request_count,interval)
      if @total_request_time > 0
        # determine the average request length
        report_data[:average_request_length] = average(@total_request_time,@request_count)
      end
    end
    
    return report_data
  end
  
  # Given a total and a count, returns a string-formatted average 
  def average(total,count)
    avg = total/count
    sprintf("%.2f", avg)
  end
  
  # The data the plugin tracks
  def init_tracking
    @request_count              = 0
    @total_request_time         = 0.0
    @bytes_sent                 = 0    
    @lines_scanned              = 0
  end
  
  def init_timing
    @previous_last_request_time = memory(:last_request_time) || Time.now-60 # analyze last minute on first invocation
    # For testing.
    if option(:log_test)
      @previous_last_request_time = Time.now-(60*60*24*300)
    end
    # Time#parse is slow so uses a specially-formatted integer to compare request times.
    @previous_last_request_time_as_timestamp = @previous_last_request_time.strftime('%Y%m%d%H%M%S').to_i
    
    # set to the time of the first request processed (the most recent chronologically)
    @last_request_time          = nil
  end
  
  # Returns nil if the timestamp is past by the previous last request time
  def parse_line(line)
    if matches = @line_definition.matches(line)
      result = @line_definition.convert_captured_values(matches[:captures],@request)
      if timestamp = result[:timestamp]
        @last_request_time = Time.parse(timestamp.to_s) if @last_request_time.nil?
        if timestamp <= @previous_last_request_time_as_timestamp
          return nil
        elsif @ignored_paths.nil? || ( @ignored_paths.is_a?(Regexp) && !@ignored_paths.match(result[:path]) )
          @request_count += 1
          if duration = result[:duration]
            @total_request_time += result[:duration] 
          end
          # if testing, show lines that were parsed
          if option(:log_test)
            p result[:path]
          end
        end # checking if the request is past the last request time
      end # timestamp check
    end # if matches
    return true
  end # def parse_line

  def silence
    old_verbose, $VERBOSE, $stdout = $VERBOSE, nil, StringIO.new
    yield
  ensure
    $VERBOSE, $stdout = old_verbose, STDOUT
  end

  def generate_log_analysis(log_path, format)
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
    else
      last_summary = now - ONE_DAY
      remember(:last_summary_time, last_summary)
    end
    # make sure we get a full run
    if now - last_summary < 60 * 60 * 22
      last_summary = now - ONE_DAY
    end

    self.class.class_eval(RLA_EXTS)

    analysis = analyze(last_summary, now, log_path, format)

    summary( :command => "request-log-analyzer --after '"                   +
                         last_summary.strftime('%Y-%m-%d %H:%M:%S')         +
                         "' --before '" + now.strftime('%Y-%m-%d %H:%M:%S') +
                         "' --apache-format "+format +
                         " '#{log_path}'",
             :output  => analysis )
  rescue Exception => error
    error("#{error.class}:  #{error.message}", error.backtrace.join("\n"))
  end

  def analyze(last_summary, stop_time, log_path, format)
    log_file = read_backwards_to_timestamp(log_path, last_summary)
    summary = StringIO.new
    RequestLogAnalyzer::Controller.build(
      :format       => { :apache => format },
      :output       => EmbeddedHTML,
      :file         => summary,
      :after        => last_summary,
      :before       => stop_time,
      :source_files => log_file
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

  RLA_EXTS = <<-'END_RUBY'
  class EmbeddedHTML < RequestLogAnalyzer::Output::Base

    include RequestLogAnalyzer::Output::FixedWidth::Monochrome

    def print(str)
      @io << str
    end
    alias_method :<<, :print

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
