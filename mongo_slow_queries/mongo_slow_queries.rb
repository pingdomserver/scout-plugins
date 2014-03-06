$VERBOSE=false
require "time"
require "digest/md5"
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

  def enable_profiling(db)
    # set to slow_only or higher (>100ms)
    if db.profiling_level == :off
      db.profiling_level = :slow_only
    end
  end

  def option_to_f(op_name)
    opt = option(op_name)
    opt.nil? ? opt : opt.to_f
  end

  def build_report
    database = option("database").to_s.strip
    server = option("server").to_s.strip
    ssl    = option("ssl").to_s.strip == 'true'
    connect_timeout = option_to_f('connect_timeout')
    op_timeout      = option_to_f('op_timeout')

    if server.empty?
      server ||= "localhost"
    end

    if database.empty?
      return error( "A Mongo database name was not provided.",
                    "Slow query logging requires you to specify the database to profile." )
    end

    threshold_str = option("threshold").to_s.strip
    if threshold_str.empty?
      threshold = 100
    else
      threshold = threshold_str.to_i
    end

    db = Mongo::Connection.new(server, option("port").to_i, :ssl => ssl, :slave_ok => true, :connect_timeout => connect_timeout, :op_timeout => op_timeout).db(database)
    db.authenticate(option(:username), option(:password)) if !option(:username).to_s.empty?
    enable_profiling(db)

    slow_queries = 0
    if @last_run
        selector = { 'millis' => { '$gte' => threshold }, 'ts' => { '$gt' => @last_run} }
        slow_queries = Mongo::Cursor.new(db[Mongo::DB::SYSTEM_PROFILE_COLLECTION], :selector => selector,:slave_ok=>true).count
    end

    counter(:slow_queries, slow_queries, :per => :minute)

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

end
