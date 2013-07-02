class NTPTime < Scout::Plugin
OPTIONS=<<-EOS
  ntpdate_binary:
    default: /usr/sbin/ntpdate
    name: "Location of ntpdate binary"

  host:
    default: pool.ntp.org
    name: NTP host to check
EOS

  DEFAULT_NTP_HOST = 'pool.ntp.org'

  def build_report
    host = option(:host) || DEFAULT_NTP_HOST

    ntpdate_result = `#{option(:ntpdate_binary)} -q #{host} 2>&1`
    unless $?.success?
      error("ntpdate failed to run: #{ntpdate_result}")
    end

    ntpdate_lines   = ntpdate_result.split("\n")
    ntpdate_report  = ntpdate_lines.pop
    ntpdate_servers = ntpdate_lines.grep(/^server /)

    offset = ntpdate_report[/ ntpdate.*offset ([^\s]+) sec/, 1].to_f

    report(:offset => offset, :servers => ntpdate_servers.length)
  end
end