$VERBOSE=false
require "time"
require "digest/md5"
require "mongo"
require "bson"

# MongoDB Slow Queries Monitoring plug in for scout.
# Created by Jacob Harris, based on the MySQL slow queries plugin

class ScoutMongoSlow < Scout::Plugin
  needs "mongo"

  OPTIONS=<<-EOS
    database:
      name: Mongo Database
      notes: Name of the MongoDB database to profile
    server:
      name: Mongo Server
      notes: Where mongodb is running
      default: localhost
    threshold:
      name: Threshold (millisecs)
      notes: Slow queries are >= this time in milliseconds to execute (min. 100)
      default: 100
    username:
      notes: leave blank unless you have authentication enabled
    password:
      notes: leave blank unless you have authentication enabled
    port:
      name: Port
      default: 27017
      Notes: MongoDB standard port is 27017
      attributes: advanced
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

  # In order to limit the alert body size, only the first +MAX_QUERIES+ are listed in the alert body. 
  MAX_QUERIES = 10

  def enable_profiling_v1(db)
    # set to slow_only or higher (>100ms)
    if db.profiling_level == :off
      db.profiling_level = :slow_only
    end
  end

  def enable_profiling_v2(db)
    if db.command(:profile => -1).first['was'] == 0
      db.command(:profile => 1, :slowms => @threshold)
    end
  end

  def option_to_f(op_name)
    opt = option(op_name)
    opt.nil? ? opt : opt.to_f
  end

  def build_report
    @database = option("database").to_s.strip
    @server = option("server").to_s.strip
    @port = option("port")
    @ssl    = option("ssl").to_s.strip == 'true'
    @connect_timeout = option_to_f('connect_timeout')
    @op_timeout      = option_to_f('op_timeout')

    if @server.empty?
      @server ||= "localhost"
    end

    if @database.empty?
      return error( "A Mongo database name was not provided.",
                    "Slow query logging requires you to specify the database to profile." )
    end

    threshold_str = option("threshold").to_s.strip
    if threshold_str.empty?
      @threshold = 100
    else
      @threshold = threshold_str.to_i
    end

    if using_gem_version_2?
      get_slow_queries_v2
    else
      get_slow_queries_v1
    end
  end

  def get_slow_queries_v1
    db = Mongo::Connection.new(@server, @port.to_i, :ssl => @ssl, :slave_ok => true, :connect_timeout => @connect_timeout, :op_timeout => @op_timeout).db(@database)
    db.authenticate(option(:username), option(:password)) if !option(:username).to_s.empty?
    enable_profiling_v1(db)
    report_slow_queries(db)
  rescue Mongo::ConnectionFailure => error
    error("Unable to connect to MongoDB","#{error.message}\n\n#{error.backtrace}")
    return
  rescue RuntimeError => error
    if error.message =~/Error with profile command.+unauthorized/i
      error("Invalid MongoDB Authentication", "The username/password for your MongoDB database are incorrect")
      return
    else
      raise error
    end
  end

  def get_slow_queries_v2
    client = Mongo::Client.new(["#{@host}:#{@port}"], :database => @database, :ssl => @ssl, :connection_timeout => @connect_timeout, :socket_timeout => @op_timeout, :server_selection_timeout => 1)
    client = client.with(user: @username, password: @password) unless @username.nil?
    enable_profiling_v2(client.database)
    report_slow_queries(client.database)
  rescue Mongo::Error::NoServerAvailable
    return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}, also confirm if SSL should be enabled or disabled.")
  end

  def report_slow_queries(db)
    slow_queries = []
    last_run = memory(:last_run) || Time.now
    current_time = Time.now

    # info
    selector = { 'millis' => { '$gte' => @threshold } }
    if using_gem_version_2?
      queries = db['system.profile'].find(selector).limit(20).sort("$natural" => -1).to_a
    else
      queries = Mongo::Cursor.new(db[Mongo::DB::SYSTEM_PROFILE_COLLECTION], :selector => selector,:slave_ok=>true).limit(20).sort([["$natural", "descending"]])
    end

    # reads most recent first
    # {"ts"=>Wed Dec 16 02:44:03 UTC 2009, "info"=>"query twitter_follow.system.profile ntoreturn:0 reslen:1236 nscanned:8  \nquery: { query: { millis: { $gte: 5 } }, orderby: { $natural: -1 } }  nreturned:8 bytes:1220", "millis"=>57.0}
    queries.each do |prof|
      ts = prof['ts']
      break if ts < last_run

      slow_queries << prof
    end

    elapsed_seconds = current_time - last_run
    elapsed_seconds = 1 if elapsed_seconds < 1
    # calculate per-second
    report(:slow_queries => slow_queries.size/(elapsed_seconds/60.to_f))

    if slow_queries.any?
      alert(build_alert(slow_queries))
    end
    remember(:last_run,Time.now)
  end

  def build_alert(slow_queries)
    subj = "Maximum Query Time exceeded on #{slow_queries.size} #{slow_queries.size > 1 ? 'queries' : 'query'}"
    # send a sampling of slow queries. the total # of queries + query is limited as scout will throwout large checkins.
    queries = []
    slow_queries[0..(MAX_QUERIES-1)].each do |sq|
      if q=sq['query'] and q.size > 300
        sq['query'] = q[0..300] + '...'
      end
      queries << sq
    end
    {:subject => subj, :body => queries.to_json}
  end

  # Override Binary's to_json command - we were getting errors trying to serialize binaries as part of the slow query report
  class BSON::Binary
    def to_json(*args)
      inspect
    end
  end

  def using_gem_version_2?
    @using_gem_version_2 ||= Mongo::constants.include?(:VERSION) && Mongo::VERSION.split(':').first.to_i >= 2
  end

end
