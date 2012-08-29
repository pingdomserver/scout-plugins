class RedisMonitor < Scout::Plugin
  needs 'redis', 'yaml'

  OPTIONS = <<-EOS
  client_host:
    name: Host
    notes: "Redis hostname (or IP address) to pass to the client library, ie where redis is running."
    default: localhost
  client_port:
    name: Port
    notes: Redis port to pass to the client library.
    default: 6379
  db:
    name: Database
    notes: Redis database ID to pass to the client library.
    default: 0
  password:
    name: Password
    notes: If you're using Redis' password authentication.
    attributes: password
  lists:
    name: Lists to monitor
    notes: A comma-separated list of list keys to monitor the length of.
  EOS

  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    redis = Redis.new :port     => option(:client_port),
                      :db       => option(:db),
                      :password => option(:password),
                      :host     => option(:client_host)
    begin
      info = redis.info

      report(:uptime_in_hours   => info['uptime_in_seconds'].to_f / 60 / 60)
      report(:used_memory_in_mb => info['used_memory'].to_i / MEGABYTE)
      report(:used_memory_in_kb => info['used_memory'].to_i / KILOBYTE)
      report(:role              => info['role'])
      report(:up =>1)

      counter(:connections_per_sec, info['total_connections_received'].to_i, :per => :second)
      counter(:commands_per_sec,    info['total_commands_processed'].to_i,   :per => :second)

      if info['role'] == 'slave'
        master_link_status = case info['master_link_status']
                             when 'up' then 1
                             when 'down' then 0
                             end
        report(:master_link_status => master_link_status) 
        report(:master_last_io_seconds_ago => info['master_last_io_seconds_ago'])
        report(:master_sync_in_progress => info['master_sync_in_progress'])
      end 

      # General Stats
      %w(changes_since_last_save connected_clients connected_slaves bgsave_in_progress).each do |key|
        report(key => info[key])
      end

      if option(:lists)
        lists = option(:lists).split(',')
        lists.each do |list|
          report("#{list} list length" => redis.llen(list))
        end
      end
    end
  rescue Exception=> e
    report(:up =>0)
    return error( "Could not connect to Redis.",
                  "#{e.message} \n\nMake certain you've specified correct port, DB and password, and that Redis is accepting connections." )
  end
end
