$VERBOSE=false
class MongoDatabaseStats < Scout::Plugin
  OPTIONS=<<-EOS
    username:
      notes: Leave blank unless you have authentication enabled.
    password:
      notes: Leave blank unless you have authentication enabled.
      attributes: password
    database:
      name: Mongo Database
      notes: Name of the MongoDB database to profile.
    host:
      name: Mongo Server
      notes: Where mongodb is running.
      default: localhost
      attributes: advanced
    port:
      name: Port
      default: 27017
      notes: MongoDB standard port is 27017.
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

  needs 'mongo', 'yaml'

  def option_to_f(op_name)
    opt = option(op_name)
    opt.nil? ? opt : opt.to_f
  end

  def build_report 
    @database = option('database')
    @host     = option('host') 
    @port     = option('port')
    @ssl      = option("ssl").to_s.strip == 'true'
    @connect_timeout = option_to_f('connect_timeout')
    @op_timeout      = option_to_f('op_timeout')
    if [@database,@host,@port].compact.size < 3
      return error("Connection settings not provided.", "The database name, host, and port must be provided in the advanced settings.")
    end
    @username = option('username')
    @password = option('password')

    if stats = get_stats
      report(:objects      => stats['objects'])
      report(:indexes      => stats['indexes'])
      report(:data_size    => as_mb(stats['dataSize']))
      report(:storage_size => as_mb(stats['storageSize']))
      report(:index_size   => as_mb(stats['indexSize']))
    end
  end

  def as_mb(metric)
    metric/(1024*1024).to_f
  end

  def get_stats
    if Mongo::constants.include?(:VERSION)
      # Mongo gem 2.0 and above have Mongo::VERSION
      stats_mongo_v2
    else
      # Mongo Gem < 2.0 does not have Mongo::VERSION
      stats_mongo_v1
    end
  end

  def stats_mongo_v1
    # Mongo Gem < 2.0
    begin
      connection = Mongo::Connection.new(@host,@port,:ssl=>@ssl,:slave_ok=>true,:connect_timeout=>@connect_timeout,:op_timeout=>@op_timeout)
    rescue Mongo::ConnectionFailure
      error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}, also confirm if SSL should be enabled or disabled.")
      return nil
    end
    
    # Try to connect to the database
    db = connection.db(@database)
    begin 
      db.authenticate(@username,@password) unless @username.nil?
    rescue Mongo::AuthenticationError
      error("Unable to authenticate to MongoDB Database.",$!.message)
      return nil
    end
    db.stats()
  end

  def stats_mongo_v2
    # Mongo Gem >= 2.0
    begin
      client = Mongo::Client.new(["#{@host}:#{@port}"], :database=>@database, :username=>@username, :password=>@password, :ssl=>@ssl, :connect_timeout=>@connect_timeout, :socket_timeout=>@op_timeout, :server_selection_timeout => 1, :connect=>:direct)
      db_stats = client.database.command({'dbstats' => 1}).first
      return db_stats
    rescue
      error("Unable to retrive MongoDB stats.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}, also confirm if SSL should be enabled or disabled.")
      return nil
    end
  end
end