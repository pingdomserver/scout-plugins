# 
# Created by Eric Lindvall <eric@5stops.com>
#

class NetworkThroughput < Scout::Plugin
  def build_report
    lines = IO.readlines('/proc/net/dev')[2..-1]

    lines.each do |line|
      iface, rest = line.split(':', 2).collect { |e| e.strip }
      next unless iface =~ /eth|venet/
      cols = rest.split(/\s+/)

      in_bytes, in_packets, out_bytes, out_packets = cols.values_at(0, 1, 8, 9).collect { |i| i.to_i }

      local_counter("#{iface}_in",          in_bytes / 1024.0,  :per => :second, :round => 2)
      local_counter("#{iface}_in_packets",  in_packets,         :per => :second, :round => 2)
      local_counter("#{iface}_out",         out_bytes / 1024.0, :per => :second, :round => 2)
      local_counter("#{iface}_out_packets", out_packets,        :per => :second, :round => 2)
    end
  rescue Exception => e
    error("#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end

  private
  # Would be nice to be part of scout internals
  def local_counter(name, value, options = {})
    current_time = Time.now

    if data = memory(name)
      last_time, last_value = data[:time], data[:value]
      elapsed_seconds       = current_time - last_time

      # We won't log it if the value has wrapped or enough time hasn't
      # elapsed
      if value >= last_value && elapsed_seconds >= 1
        result = value - last_value

        case options[:per]
        when :second, 'second'
          result = result / elapsed_seconds.to_f
        when :minute, 'minute'
          result = result / elapsed_seconds.to_f / 60.0
        end

        if options[:round]
          # Backward compatibility
          options[:round] = 1 if options[:round] == true

          result = (result * (10 ** options[:round])).round / (10 ** options[:round]).to_f
        end

        report(name => result)
      end
    end

    remember(name => { :time => current_time, :value => value })
  end
end
