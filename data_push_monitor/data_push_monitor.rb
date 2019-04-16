Encoding.default_external = Encoding::UTF_8
$VERBOSE=false
class DataPushMonitor < Scout::Plugin
  needs 'redis', 'sidekiq'

  # hack to load Sidekiq::Stats in version 3.0
  # require is generally discouraged in Scout plugins (use "needs" to make loading more efficient and errors more consistent)
  # used here to allow rescuing the require for older versions of Sidekiq
  require 'rubygems'
  begin; require 'sidekiq/api'; rescue LoadError; nil; end

  OPTIONS = <<-EOS
  host:
    name: Host
    notes: Redis hostname (or IP address) to pass to the client library, ie where redis is running.
    default: localhost
  port:
    name: Port
    notes: Redis port to pass to the client library.
    default: 6379
  rediss:
    name: Rediss Protocol
    notes: Whether to use the rediss protocol (specify 'true' to enable)
    attributes: advanced
  db:
    name: Database
    notes: Redis database ID to pass to the client library.
    default: 0
  username:
    name: RedisToGo Username
    notes: If you're using RedisToGo.
    attributes: advanced
  password:
    name: Password
    notes: If you're using Redis' username/password authentication.
    attributes: password
  namespace:
    name: Namespace
    notes: Redis namespace used for Sidekiq keys
  EOS

  def build_report
    protocol = option(:rediss).to_s.strip == 'true' ? 'rediss://' : 'redis://'
    auth = [(option(:username) || ""), option(:password)].compact.join(':')
    path = "#{option(:host)}:#{option(:port)}/#{option(:db)}"

    url = protocol
    url += "#{auth}@" if auth && auth != ':'
    url += path

    Sidekiq::Logging.logger = nil unless $VERBOSE

    Sidekiq.configure_client do |config|
      config.redis = { :url => url, :namespace => option(:namespace) }
    end

    begin
      stats = Sidekiq::Stats.new
      data_push_queue_size = stats.queues["data_push"]
      report(:queue_size => data_push_queue_size)
      
    end
  rescue Exception => e
    return error( "Could not connect to Redis.",
                  "#{e.message} \n\nMake certain you've specified the correct host and port, DB, username, and password, and that Redis is accepting connections.\n\n#{e.backtrace}" )
  end
end
