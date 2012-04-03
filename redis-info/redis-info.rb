class RedisMonitor < Scout::Plugin
  needs 'redis', 'yaml'

  OPTIONS = <<-EOS
  client_host:
    name: Host
    notes: "Redis hostname (or IP address) to pass to the client library, ie where redis is running.  "
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

    down_at = memory(:down_at)

    begin
      info = redis.info

      report(:uptime_in_hours   => info['uptime_in_seconds'].to_f / 60 / 60)
      report(:used_memory_in_mb => info['used_memory'].to_i / MEGABYTE)
      report(:used_memory_in_kb => info['used_memory'].to_i / KILOBYTE)

      counter(:connections_per_sec, info['total_connections_received'].to_i, :per => :second)
      counter(:commands_per_sec,    info['total_commands_processed'].to_i,   :per => :second)

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

      if down_at # it's do
        alert("OK - Redis is up", "Was down #{(Time.now.to_i - down_at.to_i) / 60} minutes (since #{down_at})")
      end
      down_at = nil
    rescue Errno::ECONNREFUSED => error
      if down_at.nil? # if it wasn't down, it is now
        down_at = Time.now
        alert("CRITICAL - Redis is down, or incorrect configuration",
              "Check that redis-server is running, is not blocked by firewalls, and this plugin has been configured with the correct port, DB and password.")
      end
    end

    remember(:down_at, down_at)
  end
end
