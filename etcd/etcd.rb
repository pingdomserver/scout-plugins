class EtcdStats < Scout::Plugin
  needs 'net/http', 'time', 'pry'


  def build_report
    begin
      uri = URI("http://127.0.0.1:2379/v2/stats/self")
      response = Net::HTTP.get_response(uri)
      json = JSON.parse response.body
      report(:name => json['name'])
      report(:id => json['id'])
      report(:state => json['state'])
      report(:start_time => Time.parse(json['startTime']).to_s)
      report(:leader_id => json['leaderInfo']['leader'])
      report(:leader_uptime_sec => self.parse_uptime(json['leaderInfo']['uptime']))
      report(:leader_start_time => Time.parse(json['leaderInfo']['startTime']).to_s)
      report(:rcv_append_request_cnt => json['recvAppendRequestCnt'])
      report(:send_append_request_cnt => json['recvAppendRequestCnt'])
      if (json['state'] == "StateFollower") then
        report(:rcv_bandwidth_rate => json['recvBandwidthRate'])
        report(:rcv_pkg_rate => json['recvPkgRate'])
      elsif (json['state'] == "StateLeader") then
        report(:send_bandwidth_rate => json['sendBandwidthRate'])
        report(:send_pkg_rate => json['sendPkgRate'])
      end
    rescue Errno::ECONNREFUSED => e
      return error("Connection refused, please verify if Etcd is running.",
                    "#{e.message} ")
    rescue Exception=> e
      return error( "Error using Etcd plugin.",
                    "#{e.message} ")
    end
  end

  def parse_uptime(uptime)
    time = uptime.gsub(/[a-z]/){|c| c = c + " "}.rstrip.split
    h = time.grep(/h/).first.to_i
    m = time.grep(/m/).first.to_i
    s = time.grep(/s/).first.to_i
    h * 3600 + m * 60 + s
  end
end
