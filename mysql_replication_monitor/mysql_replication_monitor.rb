require 'time'
require 'date'
class MissingLibrary < StandardError; end
class MysqlReplicationMonitor < Scout::Plugin

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

  def setup_mysql
    begin
      require 'mysql'
    rescue LoadError
      begin
        require "rubygems"
        require 'mysql'
      rescue LoadError
        raise MissingLibrary
      end
    end
    self.connection=Mysql.new(option(:host),option(:username),option(:password),nil,option(:port).to_i)
  end

  def build_report
    begin
      setup_mysql
      h=connection.query("show slave status").fetch_hash
      if h.nil?
        error("Replication not configured")
      else
        report("Binlog Position" => h["Exec_Master_Log_Pos"])
        if h["Seconds_Behind_Master"].nil?
          alert("Replication not running",
            "IO Slave: #{h["Slave_IO_Running"]}\nSQL Slave: #{h["Slave_SQL_Running"]}") unless in_ignore_window?
        elsif h["Slave_IO_Running"] == "Yes" and h["Slave_SQL_Running"] == "Yes"
          report("Seconds Behind Master"=>h["Seconds_Behind_Master"])
        else
          alert("Replication not running",
            "IO Slave: #{h["Slave_IO_Running"]}\nSQL Slave: #{h["Slave_SQL_Running"]}") unless in_ignore_window?
        end
      end
    rescue  MissingLibrary=>e
      error("Could not load all required libraries",
            "I failed to load the mysql library. Please make sure it is installed.")
    rescue Mysql::Error=>e
      error("Unable to connect to mysql: #{e}")
    rescue Exception=>e
      error("Got unexpected error: #{e} #{e.class}", e.backtrace.join('\n'))
    end
  end

  def in_ignore_window?
    if s=option(:ignore_window_start) && e=option(:ignore_window_end)
      start_time = Time.parse("#{Date.today} #{s}")
      end_time = Time.parse("#{Date.today} #{e}")

      if start_time<end_time
        return(Time.now > start_time and Time.now < end_time)
      else
        return(Time.now > start_time or Time.now < end_time)
      end
    else
      false
    end
  end

end
