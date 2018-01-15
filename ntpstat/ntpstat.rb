class NTPStat < Scout::Plugin

  OPTIONS=<<-EOS
    uptime_interval:
      default: 1
      name: Uptime interval in minutes
  EOS

  def build_report
    # Check the interval, add 10 seconds buffor
    unless Time.now.to_i - memory(:last_run_time).to_i >= (option(:uptime_interval).to_i) * 60 - 10
      report_from_memory
    else
      output = `ntpstat`

      if $?.success?
        report(:NSync => 1)

        within = output[/time correct to within (\d+) ms/, 1].to_i
        report(:accuracy_in_milliseconds => within)

        interval = output[/polling server every (\d+) s/, 1].to_i
        report(:polling_interval_in_seconds => interval)

        remember_values(interval, within, 1, Time.now.to_i)
      else
        report_from_memory(nsync=0)
      end
    end
  rescue => boom
    error(boom.message)
  end

  def report_from_memory(nsync=memory(:NSync).to_i, time=memory(:last_run_time))
    remember_values(memory(:interval).to_i, memory(:within).to_i, nsync, time)
    report(:NSync => nsync,
           :accuracy_in_milliseconds => memory(:within).to_i,
           :polling_interval_in_seconds => memory(:interval).to_i)
  end

  def remember_values(interval, within, nsync, time)
    remember(:interval => interval,
             :within => within,
             :NSync => nsync,
             :last_run_time => time)
  end
end
