class NTPTime < Scout::Plugin
OPTIONS=<<-EOS
  ntpdate_binary:
    default: /usr/sbin/ntpdate
    name: "Location of ntpdate binary"

  host:
    default: pool.ntp.org
    name: NTP host to check

  uptime_interval:
    default: 1
    name: Uptime interval in minutes
EOS

  DEFAULT_NTP_HOST = 'pool.ntp.org'

  def build_report
    if Time.now.to_i - memory(:last_run_time).to_i < (option(:uptime_interval).to_i) * 60 - 10
      report_from_memory
    else
      host = option(:host) || DEFAULT_NTP_HOST

      ntpdate_result = `#{option(:ntpdate_binary)} -q #{host} 2>&1`

      error("ntpdate failed to run: #{ntpdate_result}") unless $?.success?

      ntpdate_lines   = ntpdate_result.split("\n")
      ntpdate_report  = ntpdate_lines.pop
      ntpdate_servers = ntpdate_lines.grep(/^server /)

      offset = ntpdate_report[/ ntpdate.*offset ([^\s]+) sec/, 1].to_f

      report(:offset => offset, :servers => ntpdate_servers.length)
      remember_values(offset, ntpdate_servers.length, Time.now.to_i)
    end
  end

  def report_from_memory(time=memory(:last_run_time))
    remember_values(memory(:offset).to_f, memory(:servers).to_i, time)
    report(:offset  => memory(:offset).to_f,
           :servers => memory(:servers).to_i)
  end

  def remember_values(offset, servers, time)
    remember(:offset        => offset,
             :servers       => servers,
             :last_run_time => time)
  end
end
