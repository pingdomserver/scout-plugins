class ProcessUptimeDriftMonitor < Scout::Plugin
  OPTIONS=<<-EOS
    process_name:
      name: Process name
      notes: Process you want to monitor
    ps_command:
      name: The Process Status (ps) Command
      notes: The command with options. The default works on most systems.
      default: ps aux
    max_drift:
      name: Max drift
      notes: Max uptime difference between processes
      default: 86400
    generate_alert:
      name: Generate alet
      notes: Send alert when stale process found
      default: false
  EOS

  needs 'date'

  def build_report
    if option(:process_name)
      time_array = processes_start_times.lines.map do |line|
        Time.parse(line.chomp)
      end
      drift = time_array.max - time_array.min
      report(:"time_drift_#{option(:process_name)}" => drift)
      if option(:generate_alert) == "true" && drift > Float(option(:max_drift))
        alert("Drifter process: #{option(:process_name)}, time drift: #{drift}")
      end
    end
  end

  private

  # Assumes that uptime is in the 9th column
  def processes_start_times
    %x(#{option(:ps_command)} | grep #{option(:process_name)} | grep -v grep | awk '{print $9}')
  end
end
