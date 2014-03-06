$VERBOSE=false
class PerconaHeartbeat < Scout::Plugin

  OPTIONS=<<-EOS
    pt_heartbeat_binary:
      name: pt_heartbeat binary
      notes: full path to the pt_heartbeat binary as installed by the percona toolkit.
      default: /usr/bin/pt-heartbeat
    pt_heartbeat_config:
      name: pt-hearbeat config file
      notes: full path to the pt_heartbeat config file as deployed by your config management system.
      default: "/etc/percona-toolkit/pt-heartbeat.conf"
  EOS

  def build_report
    pt_binary = option(:pt_heartbeat_binary)
    pt_config = option(:pt_heartbeat_config)

    # fail if pt_heartbeat binary is not found
    unless pt_heartbeat_binary_exists?
      return error("#{option(:pt_heartbeat_binary)} not found on the filesystem.")
    end

    # fail if pt_heartbeat.conf is not found
    unless pt_heartbeat_config_exists?
      return error("#{option(:pt_heartbeat_config)} not found on the filesystem.")
    end

    # pt_heartbeat outputs a number, this is the amount of seconds it thinks
    # the slave is behind the master based on `percona.heartbeat` in mysql.
    report(:seconds_behind_master=>seconds_behind_master(pt_binary, pt_config))
  end

  def pt_heartbeat_binary_exists?
    File.exists?(option(:pt_heartbeat_binary))
  end

  def pt_heartbeat_config_exists?
    File.exists?(option(:pt_heartbeat_config))
  end

  def seconds_behind_master(pt_binary, pt_config)
    seconds_behind = `#{pt_binary} --config #{pt_config}`.to_i
    return seconds_behind
  end
end

