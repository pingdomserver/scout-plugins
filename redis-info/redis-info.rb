class RedisMonitor < Scout::Plugin
  needs 'redis', 'yaml'

  OPTIONS = <<-EOS
  client_port:
    name: Port
    notes: Redis port to pass to the client library.
    default: 6379
  client_db:
    name: Database
    notes: Redis database ID to pass to the client library.
    default: 0
  client_password:
    name: Password
    notes: If you're using Redis' password authentication.
  lists:
    name: Lists to monitor
    notes: A comma-separated list of list keys to monitor the length of.
  EOS

  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    redis = Redis.new :port     => option(:client_port),
                      :db       => option(:db),
                      :password => option(:password)
    begin
      info = redis.info
    rescue Errno::ECONNREFUSED => error
      return error( "Could not connect to Redis.",
                    "Make certain you've specified correct port, DB and password." )
    end

    # convert hash keys to symbols
    info.keys.each{|k|info[k.to_sym]=info.delete(k)}

    report(:uptime_in_hours   => info['uptime_in_seconds'].to_f / 60 / 60)
    report(:used_memory_in_mb => info['used_memory'].to_i / MEGABYTE)
    report(:used_memory_in_kb => info['used_memory'].to_i / KILOBYTE)

    counter(:connections_per_sec, info['total_connections_received'].to_i, :per => :second)
    counter(:commands_per_sec,    info['total_commands_processed'].to_i,   :per => :second)

    # General Stats
    %w(changes_since_last_save connected_clients connected_slaves bgsave_in_progress).each do |key|
      report(key => info[key.intern])
    end

    if option(:lists)
      lists = option(:lists).split(',')
      lists.each do |list|
        report("#{list} list length" => redis.llen(list))
      end
    end
  end
end