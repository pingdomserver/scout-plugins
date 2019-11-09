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
  queues:
    name: Queues
    notes: "Resque queues to monitor: '*' or 'foo,bar'"
    default: '*'
  EOS

  def build_report
    Resque.redis = option(:redis)
    Resque.redis.namespace = option(:namespace) unless option(:namespace).nil?
    queues = (option(:queues) || '*').split(',')
    queues.reject! { |queue| queue == '*' }

    queue_count = 0
    Resque.queues.sort.each do |queue|
      next unless queues.empty? or queues.include?(queue)
      break unless queue_count < 20
      report queue => Resque.size(queue)
      queue_count += 1
    end
  end

end
