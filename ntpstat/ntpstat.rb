class NTPStat < Scout::Plugin

  OPTIONS=<<-EOS
    uptime_interval:
      default: 1
      name: Uptime interval in minutes
  EOS

  def build_report
    init_values if memory(:within).nil?
    output = `ntpstat`

    if Time.now.to_i - memory(:last_run_time).to_i > option(:uptime_interval).to_i * 60

      remember(:last_run_time => Time.now.to_i)

      if $?.success?
        report(:NSync => 1)

        within = output[/time correct to within (\d+) ms/, 1].to_i
        report(:accuracy_in_milliseconds => within)

        interval = output[/polling server every (\d+) s/, 1].to_i
        report(:polling_interval_in_seconds => interval)

        remember_values(interval, within, 1)
      else
        remember_values(memory(:interval), memory(:within), 0)
        report(:NSync => 0, :accuracy_in_milliseconds => memory(:within), :polling_interval_in_seconds => memory(:interval))
      end
    else
      remember_values(memory(:interval), memory(:within), memory(:NSync))
      report(:NSync => memory(:NSync), :accuracy_in_milliseconds => memory(:within), :polling_interval_in_seconds => memory(:interval))
    end
  rescue => boom
    error(boom.message)
  end

  def remember_values(interval, within, nsync)
    remember(:interval => interval, :within => within, :NSync => nsync)
  end

  def init_values
    remember(:last_run_time => Time.now.to_i - 2 * (option(:uptime_interval).to_i * 60))
    remember(:interval => 0, :within => 0, :NSync => 0)
  end
end
