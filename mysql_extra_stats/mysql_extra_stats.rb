class MysqlExtraStats < Scout::Plugin
  OPTIONS=<<-EOS
  user:
    name: MySQL username
    notes: Specify the username to connect with
    default: root
  password:
    name: MySQL password
    notes: Specify the password to connect with
    attributes: password
  host:
    name: MySQL host
    notes: Specify something other than 'localhost' to connect via TCP
    default: localhost
  port:
    name: MySQL port
    notes: Specify the port to connect to MySQL with (if nonstandard)
  socket:
    name: MySQL socket
    notes: Specify the location of the MySQL socket
  EOS

  needs 'mysql'

  def build_report
    # get_option returns nil if the option value is blank
    user     = get_option(:user) || 'root'
    password = get_option(:password)
    host     = get_option(:host)
    port     = get_option(:port)
    socket   = get_option(:socket)

    mysql = Mysql.connect(host, user, password, nil, (port.nil? ? nil : port.to_i), socket)
    mysql_status = {}
    result = mysql.query('SHOW /*!50002 GLOBAL */ STATUS')
    result.each do |row|
      mysql_status[row.first] = row.last.to_i
    end
    result.free

    counters = %w(Aborted_clients
                  Opened_tables
                  Opened_table_definitions
                  Opened_files
                  Threads_created
                  Created_tmp_tables
                  Created_tmp_disk_tables
                  )
    counters.each do |counter|
      counter(counter, mysql_status[counter], :per => :second)
    end

    gauges = %w(Threads_running
                Threads_cached
                Open_tables
                Open_table_definitions
                Open_files
               )
    gauges.each do |gauge|
      report(gauge => mysql_status[gauge])
    end
  end

  # Returns nil if an empty string
  def get_option(opt_name)
    val = option(opt_name)
    return (val.is_a?(String) and val.strip == '') ? nil : val
  end
end
