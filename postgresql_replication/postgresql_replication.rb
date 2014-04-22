class PostgresqlReplication < Scout::Plugin

  needs 'pg'
  
  OPTIONS=<<-EOS
    user:
      name: PostgreSQL username
      notes: Specify the username to connect with
    password:
      name: PostgreSQL password
      notes: Specify the password to connect with
      attributes: password
    host:
      name: PostgreSQL host
      notes: Specify the host name of the PostgreSQL server. If the value begins with
              a slash it is used as the directory for the Unix-domain socket. An empty
              string uses the default Unix-domain socket.
      default: localhost
    dbname:
      name: Database
      notes: The database name to monitor
      default: postgres
    port:
      name: PostgreSQL port
      notes: Specify the port to connect to PostgreSQL with
      default: 5432
  EOS

  NON_COUNTER_ENTRIES = ['total_lag']
  
  def build_report
    report = {}
    
    begin
      PGconn.new(:host=>option(:host), :user=>option(:user), :password=>option(:password), :port=>option(:port).to_i, :dbname=>option(:dbname)) do |pgconn|

        result = pgconn.exec("SELECT max(total_lag),
                                     sum(CASE WHEN state ilike 'catchup' 
                                              THEN 1::INT ELSE 0 END) AS
                                     replicas_catching_up
                                FROM pg_monitoring_lag_info()");
        row = result[0]

        row.each do |name, val|
          if NON_COUNTER_ENTRIES.include?(name)
            report[name] = val.to_i
          else
            counter(name,val.to_i,:per => :second)
          end
        end

        result = pgconn.exec('select pg_monitoring_time_since_replay 
                                  as time_since_replay')
        row = result[0]
        report['time_since_replay'] = row.time_since_replay.to_i
      end

    rescue PGError => e
      return errors << {:subject => "Unable to connect to PostgreSQL.",
                        :body => "Scout was unable to connect to the PostgreSQL server: \n\n#{e}\n\n#{e.backtrace}"}
    end

    report(report) if report.values.compact.any?
  end
end
