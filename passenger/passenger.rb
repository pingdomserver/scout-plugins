#
# This combines the passenger_memory_stats and passenger_status plugins
# and removes the notification that should be triggers
#
# Combination by Eric Lindvall <eric@sevenscale.com>
#

class PassengerStats < Scout::Plugin

  OPTIONS=<<-EOS
  passenger_memory_stats_command:
    name: The Passenger Memory Stats Command
    notes: The full path to the passenger-memory-stats command (possibly with sudo).
    default: sudo /usr/bin/passenger-memory-stats
  passenger_status_command:
    name: The Passenger Status Command
    notes: The full path to the passenger-status command (possibly with sudo).
    default: sudo /usr/bin/passenger-status
  EOS

  def build_report
    passenger_status
    memory_stats
  rescue Exception => e
    error "Error while executing plugin: #{e.class}: #{e.message}"
  end

  private
  def passenger_status
    cmd  = option(:passenger_status_command) || "passenger-status"
    data = `#{cmd} 2>&1`
    unless $?.success?
      error "Could not get data from command: #{cmd}", "Error:  #{data}"
      return
    end

    stats = {}

    # Passenger < 4 and passenger >= 4 report different stats. This loop extracts both formats.
    data.each_line do |line|
      if line =~ /^max\s+=\s(\d+)/
        stats["passenger_max_pool_size"] = $1
      elsif line =~ /^count\s+=\s(\d+)/
        stats["passenger_process_current"] = $1
      elsif line =~ /^active\s+=\s(\d+)/
        stats["passenger_process_active"] = $1
      elsif line =~ /^inactive\s+=\s(\d+)/
        stats["passenger_process_inactive"] = $1
      elsif line =~ /^Waiting on global queue: (\d+)/
        stats["passenger_queue_depth"] = $1
      elsif line =~ /^Max pool size +: (\d+)/ # passenger 4
        stats["passenger_max_pool_size"] = $1
      elsif line =~ /^Processes  +: (\d+)/   # passenger 4
        stats["passenger_process_current"] = $1
      elsif line =~ /^\s+Requests in queue: (\d+)/  # passenger 4
        stats["passenger_queue_depth"] ||= 0
        stats["passenger_queue_depth"] += $1.to_i  
      end
    end

    report(stats)
  end

  def memory_stats
    cmd  = option(:passenger_memory_stats_command) || "passenger-memory-stats"
    data = `#{cmd} 2>&1`
    unless $?.success?
      error "Could not get data from command: #{cmd}", "Error:  #{data}"
      return
    end

    table        = nil
    headers      = nil
    field_format = nil
    stats        = Hash.new { |h,k| h[k] = 0.0 }

    data.each_line do |line|
      line = line.gsub(/\e\[\d+m/,'')
      if line =~ /^\s*-+\s+(Apache|Passenger|Nginx)\s+processes/
        table        = $1.downcase
        headers      = nil
        field_format = nil
      elsif table and line =~ /^\s*###\s+Processes:\s*(\d+)/ and table != 'passenger'
        stats["#{table}_processes"] = $1
      elsif table and line =~ /^[A-Za-z]/
        headers      = line.scan(/\S+\s*/)
        field_format = headers.map { |h| "A#{h.size - 1}" }.join("x").
            sub(/\d+\z/, "*")
        headers.map! { |h| h.strip.downcase }
      elsif table and headers and line =~ /^\d/
        fields = Hash[*headers.zip(line.strip.unpack(field_format)).flatten]
        stats["#{table}_vmsize_total"]  += as_mb(fields["vmsize"])
        stats["#{table}_private_total"] += as_mb(fields["private"])
      end
    end

    report(stats)
  end

  def as_mb(memory_string)
    num = memory_string.to_f
    case memory_string
      when /\bB/i
        num / 1024.0 / 1024.0
      when /\bKB/i
        num / 1024.0
      when /\bGB/i
        num * 1024.0
      else
        num
    end
  end
end