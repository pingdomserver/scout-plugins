class GaleraClusterStatus < Scout::Plugin
  OPTIONS=<<-EOS
    mysql_command:
      default: sudo mysql
      name: Command to run the mysql client 
  EOS

  def build_report
    @mysql_command = option(:mysql_command) || "sudo mysql"
    status = mysql_query("show status like 'wsrep%'")
    report(
      :local_state => status[:wsrep_local_state].to_i,
      :local_state_comment => status[:wsrep_local_state_comment],
      :cluster_status => status[:wsrep_cluster_status],
      :ready => status[:wsrep_ready],
      :connected => status[:wsrep_connected]
    )

  end

  def mysql_query(query)
    begin
       result = `#{@mysql_command} -e "#{query}"`
       if $?.success?
         output = {}
         result.split(/\n/).each do |line|
            row = line.split(/\t/)
            output[row.first.to_sym] = row.last
         end
         output
       else
         raise MysqlConnectionError, result
       end
    rescue Exception => e
       raise MysqlConnectionError, e
    end
  end

  class MysqlConnectionError < Exception
  end
end