$VERBOSE=false
class MongoServerStatus < Scout::Plugin
  OPTIONS=<<-EOS
    host:
      name: Mongo Server
      notes: Where mongodb is running.
      default: localhost
    username:
      notes: Leave blank unless you have authentication enabled.
    password:
      notes: Leave blank unless you have authentication enabled.
      attributes: password
    port:
      name: Port
      default: 27017
      notes: MongoDB standard port is 27017.
    ssl:
      name: SSL
      default: false
      notes: Specify 'true' if your MongoDB is using SSL for client authentication.
      attributes: advanced
    connect_timeout:
      name: Connect Timeout
      notes: The number of seconds to wait before timing out a connection attempt.
      default: 30
      attributes: advanced
    op_timeout:
      name: Operation Timeout
      notes: The number of seconds to wait for a read operation to time out. Disabled by default.
      attributes: advanced
  EOS

  needs 'mongo', 'yaml'

  def option_to_f(op_name)
    opt = option(op_name)
    opt.nil? ? opt : opt.to_f
  end

  def build_report 
    # check if options provided
    @host     = option('host') 
    @port     = option('port')
    @ssl      = option("ssl").to_s.strip == 'true'
    if [@host,@port].compact.size < 2
      return error("Connection settings not provided.", "The host and port must be provided in the advanced settings.")
    end
    @username = option('username')
    @password = option('password')
    @connect_timeout = option_to_f('connect_timeout')
    @op_timeout      = option_to_f('op_timeout')
    
    if(Mongo::constants.include?(:VERSION) && Mongo::VERSION.split(':').first.to_i >= 2)
      get_server_status_v2
    else
      get_server_status_v1
    end
  end

  def get_server_status_v1
    begin
      connection = Mongo::Connection.new(@host,@port,:ssl=>@ssl,:slave_ok=>true,:connect_timeout=>@connect_timeout,:op_timeout=>@op_timeout)
    rescue Mongo::ConnectionFailure
      return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}. Also confirm if SSL should be enabled or disabled.")
    end
    
    # Try to connect to the database
    @admin_db = connection.db('admin')
    begin 
      @admin_db.authenticate(@username,@password) unless @username.nil?
    rescue Mongo::AuthenticationError
      return error("Unable to authenticate to MongoDB Database.",$!.message)
    end
    
    stats = @admin_db.command('serverStatus' => 1)
    get_server_status(stats)
  end

  def get_server_status_v2
    client = Mongo::Client.new(["#{@host}:#{@port}"], :database => 'admin', :ssl => @ssl, :connection_timeout => @connect_timeout, :socket_timeout => @op_timeout, :server_selection_timeout => 1, :connect => :direct)
    client = client.with(user: @username, password: @password) unless @username.nil?
    stats = client.database.command(:serverStatus => 1).first
    get_server_status(stats)
  rescue Mongo::Error::NoServerAvailable
    return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}, also confirm if SSL should be enabled or disabled.")
  end
  
  def get_server_status(stats)
    if stats['indexCounters'] and stats['indexCounters']['btree']
      counter(:btree_accesses, stats['indexCounters']['btree']['accesses'], :per => :second)
    
      misses = stats['indexCounters']['btree']['misses']
      hits   = stats['indexCounters']['btree']['hits']
      if mem_misses = memory(:btree_misses) and mem_hits = memory(:btree_hits)
        ratio = (misses-mem_misses).to_f/(hits-mem_hits).to_f
        report(:btree_miss_ratio => ratio*100) unless ratio.nan?
      end
      remember(:btree_misses,misses)
      remember(:btree_hits,hits)
    end
    
    if stats['globalLock']
      lock_time  = stats['globalLock']['lockTime']
      lock_total = stats['globalLock']['totalTime']
      if mem_lock_time = memory(:global_lock_lock_time) and mem_lock_total = memory(:global_lock_total_time)
        ratio = (lock_time-mem_lock_time).to_f/(lock_total-mem_lock_total).to_f
        report(:global_lock_ratio => ratio*100) unless ratio.nan?
      end
      remember(:global_lock_lock_time,lock_time)
      remember(:global_lock_total_time,lock_total)
    end
    
    # ops
    counter(:op_inserts, stats['opcounters']['insert'], :per => :second)
    counter(:op_queries, stats['opcounters']['query'], :per => :second)
    counter(:op_updates, stats['opcounters']['update'], :per => :second)
    counter(:op_deletes, stats['opcounters']['delete'], :per => :second)
    counter(:op_get_mores, stats['opcounters']['getmore'], :per => :second)

    # connections
    report(:connections_current   => stats['connections']['current'])
    report(:connections_available => stats['connections']['available'])

  end

  # Handles 3 metrics - a counter for the +divended+ and +divisor+ and a ratio, named +ratio_name+, 
  # of the dividend / divisor.
  def count_and_ratio(dividend,divisor,ratio_name)
    if mem_divisor = memory("_counter_#{divisor.keys.first.to_s}") and mem_dividend = memory("_counter_#{dividend.keys.first.to_s}")
      divisor_count   = divisor.values.first - mem_divisor[:value]
      dividend_count = dividend.values.first - mem_dividend[:value]
      ratio = dividend_count.to_f / divisor_count.to_f
      report(ratio_name => ratio*100) unless ratio.nan?
    end
    counter(divisor.keys.first, divisor.values.first, :per => :second)
    counter(dividend.keys.first, dividend.values.first, :per => :second)
  end
end
