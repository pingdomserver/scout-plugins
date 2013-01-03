require 'time'
require 'date'
class MysqlReplicationMonitor < Scout::Plugin
  needs 'mysql'

  OPTIONS=<<-EOS
  host:
    name: Host
    notes: The slave host to monitor
    default: 127.0.0.1
  port:
    name: Port
    notes: The port number on the slave host
    default: 3306
  username:
    name: Username
    notes: The MySQL username to use
    default: root
  password:
    name: Password
    notes: The password for the mysql user
    default:
    attributes: password
  ignore_window_start:
    name: Ignore Window Start
    notes: Time to start ignoring replication failures. Useful for disabling replication for backups. For Example, 7:00pm
    default:
  ignore_window_end:
    name: Ignore Window End
    notes: Time to resume alerting on replication failure. For Example,  2:00am
    default:
  EOS

  attr_accessor :connection

  def build_report
    begin
      self.connection = Mysql.new(option(:host), option(:username), option(:password), nil, option(:port).to_i)
      h = connection.query("show slave status").fetch_hash
      down_at = memory(:down_at)
      if h.nil?
        error("Replication not configured")
      elsif h["Seconds_Behind_Master"].nil? and !down_at
        unless in_ignore_window?
          alert("Replication not running", alert_body(h)) 
          down_at = Time.now
        end
      elsif h["Slave_IO_Running"] == "Yes" and h["Slave_SQL_Running"] == "Yes"
        if down_at
          alert("Replication running again","Replication was not running for #{(Time.now - down_at).to_i} seconds")
          down_at = nil
        end
      elsif !down_at
        unless in_ignore_window?
          alert("Replication not running", alert_body(h)) 
          down_at = Time.now
        end
      end
      report("Seconds Behind Master" => h["Seconds_Behind_Master"]) if h && h["Seconds_Behind_Master"]
      remember(:down_at, down_at)
    rescue Mysql::Error => e
      error("Unable to connect to MySQL", e.to_s)
    end
  end

  def in_ignore_window?
    if s = option(:ignore_window_start) && e = option(:ignore_window_end)
      start_time = Time.parse("#{Date.today} #{s}")
      end_time = Time.parse("#{Date.today} #{e}")

      if start_time < end_time
        return (Time.now > start_time and Time.now < end_time)
      else
        return (Time.now > start_time or Time.now < end_time)
      end
    else
      false
    end
  end

  def alert_body(h)
    """
IO Slave Running: #{h["Slave_IO_Running"]}
SQL Slave Running: #{h["Slave_SQL_Running"]}

Last Errno: #{h["Last_Errno"]}
Last Error: #{h["Last_Error"]}

Last IO Errno: #{h["Last_IO_Errno"]}
Last IO Error: #{h["Last_IO_Error"]}

Last_SQL_Errno: #{h["Last_SQL_Errno"]}
Last SQL Error: #{h["Last_SQL_Error"]}
"""
  end

end
