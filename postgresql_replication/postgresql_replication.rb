class PostgresqlReplication < Scout::Plugin
  needs 'pg'

  OPTIONS=<<-EOS
    user:
      name: PostgreSQL username
      notes: Specify the username to connect as.
    password:
      name: PostgreSQL Password
      attributes: password
    host:
      name: PostgreSQL Host
      notes: Specify the host name of the PostgreSQL server. If the value begins with
              a slash it is used as the directory for the Unix-domain socket. An empty
              string uses the default Unix-domain socket.
      default: localhost
    standby_host:
      name: PostgreSQL Standby Host
      notes: Specify the hostname or IP address of the standby server.  If this is non-null, we'll get the replay lag.
    dbname:
      name: Database
      notes: The database name to monitor
      default: postgres
    port:
      name: PostgreSQL port
      notes: Specify the port to connect to PostgreSQL with
      default: 5432
  EOS

  def build_report
    report = {"synced" => 0}

    begin
      PGconn.new(:host=>option(:host), :user=>option(:user), :password=>option(:password), :port=>option(:port).to_i, :dbname=>option(:dbname)) do |pgconn|
        if (pgconn.server_version / 10000) >= 10
          query = "select state, sent_lsn as sent_location from pg_stat_replication;"
        else
          query = "select state, sent_location from pg_stat_replication;"
        end
        result = pgconn.exec(query)
        row = result[0]
        row.each do |k,v|
          report[k] = v
        end
        report["streaming"] = 1
        if report["state"] != "streaming"
           report["streaming"] = 0
        end
        query = "show archive_mode;"
        result = pgconn.exec(query)
        row = result[0]
        row.each do |k,v|
          if v == "on"
            archive_mode = 1
          else
            archive_mode = 0
          end
          report[k] = archive_mode
        end
      end
    rescue PGError => e
      return errors << {:subject => "Unable to connect to PostgreSQL.",
                        :body => "Scout was unable to connect to the PostgreSQL server: \n\n#{e}\n\n#{e.backtrace}"}
    rescue IndexError => e
      return errors << {:subject => "Replication has not occured yet.",
                        :body => "It seems that PostgreSQL hasn't registered any replication."}
    end

    # And now we connect to the standby and see what we can get:
    unless option(:standby_host).nil? || option(:standby_host) == ""
      begin
        PGconn.new(:host => option(:standby_host), :user => option(:user), :password => option(:password), :port => option(:port), :dbname => option(:dbname)) do |pgconn|
          if (pgconn.server_version / 10000) >= 10
            query = "select pg_last_wal_receive_lsn() AS pg_last_xlog_receive_location, now() - pg_last_xact_replay_timestamp() AS replication_delay;"
          else
            query = "select pg_last_xlog_receive_location(), now() - pg_last_xact_replay_timestamp() AS replication_delay;"
          end
          result = pgconn.exec(query)
          row = result[0]
          report["standby_receive_location"] = row["pg_last_xlog_receive_location"]
          delay = row["replication_delay"]

          if delay.include?(":")
             arr = delay.split(":")
             hours = arr.first.to_i * 3600
             minutes = arr[1].to_i * 60
             seconds = arr.last.to_f
             report['replication_delay'] = hours+minutes+seconds
          end

          if report['replication_delay'] < 90
             report['synced'] = 1
          end

          if report["sent_location"] == report["standby_receive_location"]
             report["synced"] = 2
          end

        end
      rescue PGError => e
        return errors << {:subject => "Could not connect to standby.", :body => "Scout was unable to connect to the standby server: \n\n#{e.backtrace}"}
      end
    end
    report(report) unless report.values.compact.empty?
  end
end
