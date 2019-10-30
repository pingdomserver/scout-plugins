require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../process_uptime_drift_monitor.rb', __FILE__)

class ProcessUptimeDriftMonitorTest < Test::Unit::TestCase
  def setup
    @options = parse_defaults("process_uptime_drift_monitor") \
      .merge(process_name: "ruby")
    @plugin = ProcessUptimeDriftMonitor.new(nil, {}, @options)
  end

  def test_reports_time_difference
    @plugin.stubs(:processes_start_times).returns("2:00\n10:00")

    res = @plugin.run

    assert res[:errors].empty?
    assert res[:alerts].empty?

    reports = res[:reports]

    assert_equal reports.first[:time_drift_ruby], 28800.to_f
  end

  def test_genetates_alert
    @options.merge!(generate_alert: "true", max_drift: "1000")
    @plugin = ProcessUptimeDriftMonitor.new(nil, {}, @options)
    @plugin.stubs(:processes_start_times).returns("2:00\n10:00")

    res = @plugin.run

    refute res[:alerts].empty?

    alerts = res[:alerts]
    assert_equal alerts.first[:subject], "Drifter process: ruby, time drift: 28800.0"
  end
end
