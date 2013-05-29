class NTPStat < Scout::Plugin
  def build_report
    output = `ntpstat`
    if $?.success?
      report(:NSync => 1)

      within = output[/time correct to within (\d+) ms/, 1].to_i
      report(:accuracy_in_milliseconds => within)

      interval = output[/polling server every (\d+) s/, 1].to_i
      report(:polling_interval_in_seconds => interval)
    else
      report(:NSync => 0)
    end
  rescue => boom
    error(boom.message)
  end
end
