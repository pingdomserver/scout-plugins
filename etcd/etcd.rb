class EtcdStats < Scout::Plugin
  needs 'curb', 'time', 'pry'

  INFO = <<-EOS
  This plugin is using 'curb' gem. To use the plugin, please install 'curb'.
  EOS


  def build_report
    begin
      c = Curl::Easy.new("http://127.0.0.1:2379/v2/stats/self")
      c.perform
      response = c.body_str
      json = JSON.parse response
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
        #report(:send_bandwidth_rate => json['sendBandwidthRate'])
        #report(:send_pkg_rate => json['sendPkgRate'])
      end
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
