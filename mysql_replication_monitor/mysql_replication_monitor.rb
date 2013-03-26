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
    res={"Seconds Behind Master" => -1, "Replication Running"=>0}
    begin
      self.connection=Mysql.new(option(:host),option(:username),option(:password),nil,option(:port).to_i)
      h=connection.query("show slave status").fetch_hash
      down_at = memory(:down_at)
      if h.nil?
        error("Replication not configured")
      else
        if h["Seconds_Behind_Master"].nil? && !down_at
          if in_ignore_window?
            res["Replication Running"]=1
          else
            res["Replication Running"]=0
            down_at = Time.now
          end
        elsif h["Slave_IO_Running"] == "Yes" && h["Slave_SQL_Running"] == "Yes"
          res["Seconds Behind Master"] = h["Seconds_Behind_Master"]
          res["Replication Running"]=1
          down_at = nil if down_at
        elsif !down_at
          if in_ignore_window?
            res["Replication Running"]=1
          else
            down_at = Time.now
            res["Replication Running"]=0
          end
        end
      end
      remember(:down_at,down_at)
    rescue Mysql::Error=>e
      error("Unable to connect to MySQL",e.to_s)
    end
    report(res)
  end

  def in_ignore_window?
    if (s = option(:ignore_window_start)) && (e = option(:ignore_window_end))
      start_time = Time.parse("#{Date.today} #{s}")
      end_time = Time.parse("#{Date.today} #{e}")

      if start_time < end_time
        return Time.now > start_time && Time.now < end_time
      else
        return Time.now > start_time || Time.now < end_time
      end
    else
      false
    end
  end

end
