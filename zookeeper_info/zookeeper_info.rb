class ZookeeperMonitor < Scout::Plugin
  needs 'socket'

  OPTIONS=<<-EOS
  port:
    name: Port
    notes: ZooKeeper listening port
    default: 2181
  EOS

# Run the 4-letter command to grab the server stats from the running service
#
# This is what the output of the command in bash looks like:
# bash$ echo srvr | nc localhost 2181
#
# Zookeeper version: 3.3.3-cdh3u0--1, built on 03/26/2011 00:21 GMT
# Latency min/avg/max: 0/0/0
# Received: 68
# Sent: 67
# Outstanding: 0
# Zxid: 0x400000002
# Mode: follower
# Node count: 4

  def build_report
    # Ruby's error handling is weird, but this catches in the event that the port is incorrect, unresponsive
    begin
      # Ruby sockets! http://www.ruby-doc.org/stdlib/libdoc/socket/rdoc/index.html
      socket = TCPSocket.open("localhost", "#{option(:port)}")   
      socket.print("srvr")
      stats = socket.read

      if stats =~ /This ZooKeeper instance is not currently serving requests/i
        report(:up => 0)
        error(:subject => "Zookeeper not servic requests", :body => stats)
        return
      end

      # Let's set the variables to the outputs, based on regexes
      stats.each_line do |line|
        # This line is smarter, thanks to Dan's regex-fu
        case line
        when %r{^Latency min/avg/max: (\d+)/(\d+)/(\d+)}
          lat_min, lat_avg, lat_max = $1.to_i, $2.to_i, $3.to_i
          report(:lat_min => lat_min, :lat_avg => lat_avg, :lat_max => lat_max)
        when /^(Received|Sent): (\d+)/
          counter($1.downcase, $2.to_i, :per => :minute)
        when /^([^:]+): (\d+)$/
          name, num = $1, $2
          name = name.gsub(' ', '_').downcase
          report(name => num.to_i)
        when /^([^:]+): (\S+)$/
          name, val = $1, $2
          name = name.gsub(' ', '_').downcase
          report(name => val)
        end
      end

      report(:up => 1)
    rescue Errno::ECONNREFUSED => e
      report(:up => 0)
      error(:subject => 'Unable to connect to zookeeper', :body => "The zookeeper service is not running on the specified port (#{option(:port)}).\nFull error is:\n" + e)
    end
  end
end