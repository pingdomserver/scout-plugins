$VERBOSE=false

class ResqueQueues < Scout::Plugin

  needs 'redis', 'resque'

  OPTIONS=<<-EOS
  redis:
    name: Resque.redis
    notes: "Redis connection string: 'hostname:port' or 'hostname:port:db'"
    default: localhost:6379
  namespace:
    name: Namespace
    notes: "Resque namespace: 'resque:production'"
    default:
  EOS

  def build_report
    Resque.redis = option(:redis)
    Resque.redis.namespace = option(:namespace) unless option(:namespace).nil?

    Resque.queues.each do |queue|
      report queue => Resque.size(queue)
    end
  end

end
