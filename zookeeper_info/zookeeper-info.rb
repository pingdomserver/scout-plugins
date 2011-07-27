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
    # Zero out all the variables we want to return
    lat_min, lat_avg, lat_max, received, sent, outstanding, node_count, mode = nil

    # Ruby's error handling is weird, but this catches in the event that the port is incorrect, unresponsive
    begin
      # Ruby sockets! http://www.ruby-doc.org/stdlib/libdoc/socket/rdoc/index.html
      socket = TCPSocket.open("localhost", "#{option(:port)}")   
      socket.print("srvr")
      stats = socket.read

      # Let's set the variables to the outputs, based on regexes
      stats.each_line do |line|
        # This line is smarter, thanks to Dan's regex-fu
        lat_min, lat_avg, lat_max = $1, $2, $3 if line =~ /^Latency min\/avg\/max:\s+(\d+)+\/+(\d+)+\/+(\d+)/
        received = $1 if line =~ /^Received:\s+(\d+)/
        sent = $1 if line =~ /^Sent:\s+(\d+)/
        outstanding = $1 if line =~ /^Outstanding:\s+(\d+)/
        node_count = $1 if line =~ /^Node count:\s+(\d+)/
        mode = $1 if line =~ /^Mode:\s+(\w+)/
      end
    
      # Build the output report
      counter(:received, received.to_i,  :per => :minute)
      counter(:sent,     sent.to_i,      :per => :minute)
      report({:lat_min => lat_min, :lat_avg => lat_avg, :lat_max => lat_max, 
        :outstanding => outstanding, :node_count => node_count, :mode => mode }) 

    rescue Exception => e
      # I take liberties with error messages.
      error(:subject => 'Poopytime!', :body => 'Apparently, the zookeeper service is not running on the specified port.\nFull error is:\n' + e)
    end

  end

end