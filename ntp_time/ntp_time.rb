class NTPTime < Scout::Plugin
  needs 'net/ntp'

OPTIONS=<<-EOS
  host:
    default: pool.ntp.org
    name: NTP host to check
EOS

  DEFAULT_NTP_HOST = 'pool.ntp.org'

  def build_report
    host = option(:host) || DEFAULT_NTP_HOST

    begin
      response  = Net::NTP.get(host)
      localtime = Time.new.to_i
      offset    = (response.receive_timestamp - response.originate_timestamp) + (response.transmit_timestamp - localtime) / 2

      report(
        :receive_timestamp   => response.receive_timestamp.to_f,
        :originate_timestamp => response.originate_timestamp.to_f,
        :transmit_timestamp  => response.transmit_timestamp.to_f,
        :offset              => offset.to_f
      )

    rescue Exception => e
      error("Unable to connect to NTP server (#{host})")
      return
    end
  end
end