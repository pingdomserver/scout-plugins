class TomcatMonitor < Scout::Plugin

  OPTIONS=<<-EOS
    logdir:
      notes: "absolute path to tomcat localhost_access_log.<YYY-MM-DD>.log"
      default: /opt/jboss/server/default/log/
    exclude_filter:
      notes: "| separated list of grep -v"
      default: "| grep -v HealthCheck | grep -v SessionCheck"
    type_monitor:
      notes: grep query to narrow monitor to a transaction.  i.e. "abc.jsp".   by default, stats are overall summary
    clear_cache:
      notes:  used for testing. clears last request processed
  EOS

  def build_report
    @logdir = nil
    @last_line_processed = 0
    @last_date_processed = nil
    @request_comparison = {} # request => {:max => , :count => }
    begin
      requests = parse_logs
      parsed_requests = parse_requests(requests)
      process_requests(parsed_requests)
      report_data if @request_comparison && @request_comparison.size > 0
    rescue StandardError => trouble
      error "#{trouble} #{trouble.backtrace}"
    end
  end

  def report_data
    rpm = @request_comparison[:all][:rpm]
    rt =  @request_comparison[:all][:rt]
    max = @request_comparison[:all][:max]
    report({:throughput => rpm, :duration => rt, :max_duration => max})    
  end

  #################
  # STATS PROCESS
  #################

  def process_requests(requests)
    requests.each do |r|
      begin
        duration = r[0]
        request = r[1]
        @last_date_processed = timestamp = r[2]
        increment_request_comparison(request, timestamp, duration) #if target_include?(request)
        increment_request_comparison(:all, timestamp, duration)
      rescue StandardError => b
        # swallow Exception and keep going
      end
      store_last_date_processed(@last_date_processed, logfile)
    end
    @request_comparison.each do |r, stats|
      rpm = calc_throughput(stats[:count], stats[:start], stats[:end])
      rt = calc_request_time(stats[:total_time], stats[:count])
      @request_comparison[r][:rpm] = rpm
      @request_comparison[r][:rt] = rt
    end
  end

  def increment_request_comparison(request, timestamp, duration)
    return @request_comparison[request] = {:max => duration, :total_time => duration, :count => 1, :start => timestamp, :end => timestamp } unless @request_comparison[request]
    max = @request_comparison[request][:max]
    rt = @request_comparison[request][:total_time] + duration
    count = @request_comparison[request][:count]
    max = duration if duration > max
    start = @request_comparison[request][:start]
    count += 1
    @request_comparison[request] = {:max => max, :total_time => rt, :count => count, :start => start, :end => timestamp}
  end

  def process_slowest_requests
    process_sorted_hash top_ten(:rt)

  end

  def process_most_frequent_requests
    process_sorted_hash top_ten(:count)
  end

  def process_sorted_hash(sorted_hash)
    hash = {}
    sorted_hash.each do |k|
      hash[k.first+":throughput"] = k.last[:count] if k.first != :all
      hash[k.first+":duration"] = k.last[:total_time] if k.first != :all
      hash[k.first+":max_duration"] = k.last[:max] if k.first != :all
    end
    hash
  end

  # returns sorted array [[k, hash of values][k, hash of values]]
  def top_ten(what)
    top = @request_comparison.sort {|a,b| b[1][what]<=>a[1][what]}.collect{|k,v| [k,v] }[0,5]
  end

  def calc_throughput(count, start, zend)
    return 0 if zend - start <= 0
    count / ((zend - start) / 60)
  end

  def calc_request_time(total_rt, count)
    return 0 unless count > 0
   total_rt / count
  end

  #################
  # REQUEST PARSING
  #################

  def parse_requests(requests)
    parsed = []
    requests.each_line do |line|
      begin
        duration, request, log_timestamp = parse_line line
        request = (request.split '?')[0]                     # trim requests down that include attributes
        next unless include_this_request?(request)
        timestamp = time_from_logs log_timestamp
        parsed << [duration, request, timestamp]
      rescue StandardError => bang
        p "error parsing request, skipping line: #{line}: #{bang} #{bang.backtrace}"
      end
    end
    parsed
  end

  # after awk treatment, line should be in format: <timestamp> <duration ms> <http-method-request>
  # i.e. [23/Apr/2011:21:08:35 4 "GET:/servlet/LogoutServlet
  def parse_line(line)
    pos = 0
    duration, http_method, request, timestamp = nil
    line.split.each do |w|
      timestamp = w if pos == 0
      duration = w.to_i if pos == 1
      request = w if pos == 2
      request = request.gsub('GET','G').gsub('POST','P').gsub('DELETE','D').gsub('UPDATE','U').gsub('client','').gsub('jsp','').gsub('servlet','').gsub('.','').gsub('//','') if request
      pos += 1
    end
    return duration, request, timestamp
  end

  # convert [18/Apr/2011:22:31:17 to ruby time
  def time_from_logs(log_timestamp)
    stripped = log_timestamp.gsub('[', '').gsub('/', ' ').gsub(':', ' ')
    pos = 0
    year, month, day, hour, min, sec = nil
    stripped.split.each do |w|
      day = w if pos == 0
      month = w if pos == 1
      year = w.to_i if pos == 2
      hour = w if pos == 3
      min = w if pos == 4
      sec = w if pos == 5
      pos += 1
    end
    Time.local(year,month,day,hour,min,sec)
  end

  def timestamp_from_time(time)
    time.strftime("%d/%b/%Y:%H:%M:%S")
  end

  def include_this_request?(request)
    return true if type_monitor == '' || type_monitor == 'all'
    return true if request.include? type_monitor
    return false
  end

  def type_monitor
      type = option(:type_monitor) || ''  #slowest | most_frequent
  end

  #################
  # LOG PARSING
  #################

  # assumes format: 10.162.73.221 - - [23/Apr/2011:00:00:40 +0000] 80557 "GET /client/appraisalWorkshopPrintSignReport.jsp HTTP/1.1" 200
  # use this pattern in server.xml: '%h %l %u %t %D "%r" %s %b"'
  def parse_logs
    logs = ""
    begin
      pfc = print_file_cmd
      logs = `#{pfc} #{logfile} #{filters} | awk '{print $4 " "  $6 " "$7":"$8}'`
      p "unable to parse log" if logs.size <= 0
    rescue StandardError => bang
      # swallowing errors
      p "unable to parse log #{bang} #{bang.backtrace}"
    end
    logs
  end

  def logfile
    @logdir || logfile_absolute_path
  end

  def logfile_absolute_path
    logdir = option(:logdir) || '/opt/jboss/server/default/log/'
    logfile = (logdir + `ls -tr #{logdir} | grep localhost_access_log | tail -1`).chomp
    raise "#{logfile} does not exist" unless File.exist?(logfile)
    @logdir = logfile
    logfile
  end

  def filters
    option(:exclude_filter) || '| grep -v HealthCheck | grep -v SessionCheck'
  end

  # use cat to parse entire log file, tail -n to skip lines
  def print_file_cmd
    last_date_processed = remember_last_date_processed(logfile)
    return 'cat ' unless last_date_processed && last_date_processed.is_a?(Time)
    search_for = timestamp_from_time last_date_processed
    line = `grep --line-number #{search_for} #{logfile}`
    return 'cat ' unless line && line.size > 0
    line_number = (line.split ':')[0]       # parsing line # from front of log:  36164:10.162.73.221 - - [23/Apr/2011:15:51:46 +0000
    "tail -n+#{line_number}"
  end

  def store_last_date_processed(date, logfile)
    if option(:clear_cache)
      remember :last_date_processed => nil
      remember :last_logfile_processed => nil
    else
      remember :last_date_processed => date
      remember :last_logfile_processed => logfile
    end
  end

  def remember_last_date_processed(logfile)
    if option(:clear_cache)
      return nil
    else
      last_logfile = memory(:last_logfile_processed)
      return nil unless last_logfile == logfile
      return memory(:last_date_processed) 
    end
  end

end

