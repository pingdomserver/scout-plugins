class RedisMonitor < Scout::Plugin
  needs 'redis', 'yaml'

  attr_accessor :socket

  OPTIONS = <<-EOS
  client_host:
    name: Host
    notes: "Redis hostname (or IP address) to pass to the client library, ie where redis is running. This will be ignored if the Unix socket path is provided."
    default: localhost
  client_port:
    name: Port
    notes: Redis port to pass to the client library. This will be ignored if the Unix socket path is provided.
    default: 6379
  client_path:
    name: Unix socket path
    notes: "Redis socket path to pass to the client library (ex: /tmp/redis.sock). Host and port will be ignored if provided."
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
    if option(:client_path) and option(:client_path).length > 0
      self.socket = true
      redis = Redis.new :path     => option(:client_path),
                        :db       => option(:db),
                        :password => option(:password)
    else
      redis = Redis.new :port     => option(:client_port),
                        :db       => option(:db),
                        :password => option(:password),
                        :host     => option(:client_host)
    end

    begin
      info = redis.info

      report(:uptime_in_hours   => info['uptime_in_seconds'].to_f / 60 / 60)
      report(:used_memory_in_mb => info['used_memory'].to_i / MEGABYTE)
      report(:role              => info['role'])
      report(:up =>1)

      counter(:hits_per_sec, info['keyspace_hits'].to_i, :per => :second)
      counter(:misses_per_sec, info['keyspace_misses'].to_i, :per => :second)

      counter(:connections_per_sec, info['total_connections_received'].to_i, :per => :second)
      counter(:commands_per_sec,    info['total_commands_processed'].to_i,   :per => :second)

      if mem_hits = memory(:hits) and mem_misses = memory(:misses)
        # hits and misses since the last measure
        hits   = info['keyspace_hits'].to_i   - mem_hits
        misses = info['keyspace_misses'].to_i - mem_misses

        # total queries since the last measure
        total = hits + misses

        if total > 0
          report(:hits_ratio => 100 * hits / total)
        end
      end
      remember(:hits, info['keyspace_hits'].to_i)
      remember(:misses, info['keyspace_misses'].to_i)

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
                  "#{e.message} \n\nMake certain you've specified the correct #{self.socket ? 'Unix socket path' : 'host and port'}, DB and password, and that Redis is accepting connections." )
  end
end
