require "time"
require "digest/md5"

# MySQL Slow Queries Monitoring plug in for scout.
# Created by Robin "Evil Trout" Ward for Forumwarz, based heavily on the Rails Request
# Monitoring Plugin.
#
# See: http://blog.forumwarz.com/2008/5/27/monitor-slow-mysql-queries-with-scout
#
# Example line from a slow queries log file:
#
# Time: 080606 15:22:26
# User@Host: root[root] @ localhost []
# Query_time: 21  Lock_time: 0  Rows_sent: 18  Rows_examined: 8157
# SELECT SQL_NO_CACHE IF('2008-04-18 19:03:00' <= reports.time AND reports.time < '2008-04-20 10:21:00', 0, IF('2008-04-20 10:21:00' <= reports.time AND reports.time < '2008-04-22 01:39:00', 1, IF('2008-04-22 01:39:00' <= repo

class ScoutMysqlSlow < Scout::Plugin
  needs "elif"
  
  # In order to limit the alert body size, only the first +MAX_QUERIES+ are listed in the alert body. 
  MAX_QUERIES = 10
  
  OPTIONS=<<-EOS
  mysql_slow_log:
    default: /var/log/mysql/mysql-slow.log
    name: Full path to the MySQL slow queries log file
  minimum_query_time:
    default: 0
    name: "Minimum Query Time (sec)"
    attributes: advanced
    notes: If the log file contains queries that are less than the specified time in seconds the queries will be ignored.
  EOS
  
  def build_report
    log_file_path = option(:mysql_slow_log).to_s.strip
    return if !file_readable?(log_file_path)

    slow_query_count = 0
    all_queries = [] # all of the queries from the log file are stored here
    slow_queries = [] # only the slow queries are placed here
    sql = []
    last_run = memory(:last_run) || Time.now
    minimum_query_time = option(:minimum_query_time).to_f
    current_time = Time.now
    last_run_entry_timestamp = memory(:last_run_entry_timestamp)
    temp_timestamp=nil
    latest_entry_timestamp=nil

    # starts at the bottom of the log file, moving up
    Elif.foreach(log_file_path) do |line|
      if line =~ /^# Query_time: ([\d\.]+) .+$/
        query_time = $1.to_f
        all_queries << {:query_time => query_time, :sql => sql.reverse}
        sql = []
      elsif line =~ /^\# Time: (\d+ .*|\d{2,4}\-\d{1,2}\-\d{1,2}.*)$/
        # We now have a complete entry. capture its timestamp:
        # split w/# is for ey compatibility. 
        temp_timestamp = Time.parse($1.split('#')[0]) {|y| y < 100 ? y + 2000 : y}
        # if there was a last_run_entry_timestamp, we can quit based on comparing it to the current_entry_timestamp we just parsed.
        if last_run_entry_timestamp && temp_timestamp <= last_run_entry_timestamp
          break
        elsif all_queries.any?
          sq = all_queries.last
          if sq[:query_time] >= minimum_query_time
            # this query occurred after the last time this plugin ran and should be counted.  
            slow_queries << sq.merge({:time_of_query => temp_timestamp})
          end
        end
        latest_entry_timestamp ||= temp_timestamp # latest_entry_timestamp will be the bottom timestamp in the log. We'll use it as the watermark for next run
        # if there wasn't a last_entry_timestamp, we should break now that we have one complete log entry
        break if last_run_entry_timestamp == nil
      elsif line !~ /^(\#|use |SET timestamp)/ # an SQL query
        sql << line
      end
    end  

    elapsed_seconds = current_time - last_run
    elapsed_seconds = 1 if elapsed_seconds < 1
    # calculate per-second
    report(:slow_queries => slow_queries.size/(elapsed_seconds/60.to_f))
    if slow_queries.any?
      alert( build_alert(slow_queries,log_file_path) )
    end
    remember(:last_run,Time.now)
    remember(:last_run_entry_timestamp, latest_entry_timestamp || last_run_entry_timestamp)
  rescue Errno::ENOENT => error
    error("Unable to find the MySQL slow queries log file", "Could not find a MySQL slow queries log file at: #{option(:mysql_slow_log)}. Please ensure the path is correct.")    
  end
  
  private
  
  # Ensure (a) a file path is provided (b) exists (c) is readable. Generates an error and returns +false+ if if the file isn't readable, otherwise +true+.
  def file_readable?(path)
    unless path and not path.empty?
      error( "A path to the MySQL Slow Query log file wasn't provided.",
                    "The full path to the slow queries log must be provided. Learn more about enabling the slow queries log here: http://dev.mysql.com/doc/refman/5.1/en/slow-query-log.html" )
      return false
    end
    # File#exist? returns false if the file exists but isn't readable. This provides a more accurate error message.
    begin 
      FileTest.size(path)
    rescue Errno::EACCES
      error("The MySQL Slow Query log file isn't readable", "The log file at #{path} isn't readable by the user running Scout. Please update the file permissions to give the user access.")
    rescue Errno::ENOENT
      error("Unable to find the MySQL Slow Query log file", "Could not find a MySQL Slow Query log file at: #{path}. Please ensure the path is correct.")
    rescue
      error("Unable to read the MySQL Slow Query log file", "The log file at: #{path} couldn't be accessed (#{$!.message}).")
    end
    data_for_server[:errors].any? ? false : true
  end
  
  def build_alert(slow_queries,log_file_path)
    subj = "Maximum Query Time exceeded on #{slow_queries.size} #{slow_queries.size > 1 ? 'queries' : 'query'}"
    body = String.new
    slow_queries[0..(MAX_QUERIES-1)].each do |sq|
      body << "<strong>#{sq[:query_time]} sec query on #{sq[:time_of_query]}:</strong>\n"
      sql = sq[:sql].join
      sql = sql.size > 500 ? sql[0..500] + '...' : sql
      body << sql
      body << "\n\n"
    end # slow_queries.each
    if slow_queries.size > MAX_QUERIES
      body << "#{slow_queries.size-MAX_QUERIES} more slow queries occured. See the slow queries log file (located at #{log_file_path}) for more details."
    end
    {:subject => subj, :body => body}
  end # build_alert
end