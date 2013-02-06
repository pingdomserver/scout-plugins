require 'socket'

# Provide a comma-delimited list of host:ports. This plugin will alert you when the status
# of one or ports changes (a port that was previously online goes offline, or vice-versa).
class SimplePortCheck < Scout::Plugin

  OPTIONS=<<-EOS
    ports:
      notes: "comma-delimited list of 'host:ports' to monitor. Example: yahoo.com:80,google.com:443"
      default: "localhost:80,google.com:443,yahoo.com:80"
    retries:
      notes: "Number of retries per host/port you want to perform in the event of a closed port."
      default: 0
    sleep:
      notes: "Number of seconds you wish to sleep between retries."
      default: 0
  EOS

  def build_report
    ports        = option(:ports).split(/[ ,]+/).uniq
    retries      = option(:retries).to_i
    sleep_time   = option(:sleep).to_i
    port_status  = ports.map{|port| is_port_open?(port, retries, sleep_time)} # true=open, false=closed

    num_ports=ports.size
    num_ports_open = port_status.find_all {|status| status == true}.size


    previous_num_ports=memory(:num_ports)
    previous_num_ports_open=memory(:num_ports_open)

    # alert if the number of ports monitored or the number of ports open has changed since last time
    if num_ports !=previous_num_ports || num_ports_open != previous_num_ports_open
      subject = "Port check: #{num_ports_open} of #{ports.size} ports open"
      body=""
      ports.each_with_index do |port,index|
        body<<"#{index+1}) #{port} - #{port_status[index] ? 'open' : 'CLOSED'} \n"
      end
      alert(subject,body)
    end

    remember :num_ports => num_ports
    remember :num_ports_open => num_ports_open

    report(:num_ports_open => num_ports_open)
  end

  private

  def is_port_open?(host_and_port, retries, sleep_time)
    host,port=host_and_port.split(":")
    status  = nil
    0.upto(retries) do |i|
      begin
        s = TCPSocket.open(host, port.to_i)
        s.close
        status = true
      rescue
        status = false
      end
      sleep sleep_time unless (i == retries || status == true)
    end
    return status
  end
end
