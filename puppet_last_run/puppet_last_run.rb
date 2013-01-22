class PuppetLastRun < Scout::Plugin
  needs 'yaml'

OPTIONS=<<-EOS
  recent_runs_file:
    default: /var/lib/puppet/state/recent_runs.yaml
    name: Recent runs file
EOS

  DEFAULT_RECENT_RUNS_FILE="/var/lib/puppet/state/recent_runs.yaml"

  def build_report
    recent_runs_file = option(:recent_runs_file) || DEFAULT_RECENT_RUNS_FILE

    if File.exist?(recent_runs_file)
      actual_last_run_time = File.mtime(recent_runs_file)
      scout_last_run_time  = memory(:last_run_time)

      return if scout_last_run_time && scout_last_run_time >= actual_last_run_time

      remember :last_run_time => actual_last_run_time

      recent_array   = YAML.load_file(recent_runs_file) || []
      last_exit_code = recent_array.last || 4

      report(:success => (last_exit_code <= 2) ? 1 : 0)

    else
      error("Puppet run file does not exist")
    end
  end
end