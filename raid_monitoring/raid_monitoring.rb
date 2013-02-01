class RaidMonitoring < Scout::Plugin

  OPTIONS=<<-EOS
  nagios_check_raid_file:
    name: Nagios check raid file
    notes: File path of nagios check_raid. See: https://github.com/glensc/nagios-plugin-check_raid
    default: /usr/lib/nagios/plugins/check_raid
  EOS

  DEFAULT_NAGIOS_CHECK_RAID = '/usr/lib/nagios/plugins/check_raid'

  def build_report
    nagios_check_raid_file = option(:nagios_check_raid_file) || DEFAULT_NAGIOS_CHECK_RAID

    # give an error message if any of the needed command lines can't be found
    checks = [`which perl`]
    if checks.any?{|c|c.strip ==''}
      error_text=<<-END_ERROR_TEXT
      RaidMonitoring needs perl to run.
      ----
      Your $PATH in this environment is:
      #{ENV['PATH'].gsub(":","\n")}

      Check your PATH carefully. PATH is often different when run from a cron job.
      END_ERROR_TEXT
      error("Can not run RaidMonitoring", error_text)
    else

      result = `perl #{nagios_check_raid_file}`.strip

      if result =~ /^OK:/
        report(:status => 0)
      elsif result =~ /^WARNING:/
        report(:status => 1)
      elsif result =~ /^CRITICAL:/
        report(:status => 2)
      elsif result =~ /^UNKNOWN:/
        report(:status => 3)
      end

    end
  end
end