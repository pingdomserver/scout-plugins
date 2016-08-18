$VERBOSE=false
class MongoReplicaSetMonitoring < Scout::Plugin
  OPTIONS=<<-EOS
    host:
      name: Mongo Server
      notes: Where mongodb is running. 
      default: localhost
    username:
      notes: Leave blank unless you have authentication enabled. 
      attributes: advanced
    password:
      notes: Leave blank unless you have authentication enabled. 
      attributes: advanced,password
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

  needs 'mongo'

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
      return error("Connection settings not provided.", "The host and port must be provided in the settings.")
    end
    @username = option('username')
    @password = option('password')
    @connect_timeout = option_to_f('connect_timeout')
    @op_timeout      = option_to_f('op_timeout')

    if(Mongo::constants.include?(:VERSION) && Mongo::VERSION.split(':').first.to_i >= 2)
      get_replica_set_status_v2
    else
      get_replica_set_status_v1
    end
  end
  
  def get_replica_set_status_v1
    connection = Mongo::Connection.new(@host,@port,:ssl=>@ssl,:slave_ok=>true,:connect_timeout=>@connect_timeout,:op_timeout=>@op_timeout)
    
    # Connect to the database
    @admin_db = connection.db('admin')
    @admin_db.authenticate(@username,@password) unless @username.nil?
    replset_status = @admin_db.command({'replSetGetStatus' => 1}, :check_response => false)
    report_replica_set_status(replset_status)
  rescue Mongo::ConnectionFailure
    return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}, also confirm if SSL should be enabled or disabled.")
  end

  def get_replica_set_status_v2
    client = Mongo::Client.new(["#{@host}:#{@port}"], :database => 'admin', :ssl => @ssl, :connection_timeout => @connect_timeout, :socket_timeout => @op_timeout, :server_selection_timeout => 1, :connect => :direct)
    client = client.with(user: @username, password: @password) unless @username.nil?
    replset_status = client.database.command(:replSetGetStatus => 1).first
    report_replica_set_status(replset_status)
  rescue Mongo::Error::NoServerAvailable
    return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}, also confirm if SSL should be enabled or disabled.")
  end

  def report_replica_set_status(replset_status)
    unless replset_status['ok'] == 1
      return error("Node isn't a member of a Replica Set","Unable to fetch Replica Set status information. Error Message:\n\n#{replset_status['errmsg']}")
    end
    
    member_state = case replset_status['myState']
      when 0 
        'Starting Up'
      when 1 
        'Primary'
      when 2 
        'Secondary'
      when 3 
        'Recovering'
      when 4 
        'Fatal'
      when 5 
        'Starting up (forking threads)'
      when 6 
        'Unknown'
      when 7 
        'Arbiter'
      when 8 
        'Down'
      when 9 
        'Rollback'
    end
    
    report(:name => replset_status['set'])
    report(:member_state => member_state)
    report(:member_state_num => replset_status['myState'])

    primary = replset_status['members'].detect {|member| member['state'] == 1}
    if primary
      current_member = replset_status['members'].detect do |member|
        member['self']
      end
      
      if current_member && member_state != 'Arbiter'
        report(:replication_lag => current_member['optimeDate'] - primary['optimeDate'])
      end

      # to prevent duplicate alxrts, we only report nonzero faulty_member_count from our current primary
      if member_state == 'Primary'
        faulty_members = replset_status['members'].select { |member| [4, 6, 8].include?(member['state']) }
        report(:faulty_member_count => faulty_members.size)
      else
        report(:faulty_member_count => 0)
      end
    end  
    report(:member_healthy => (current_member && current_member['health']) ? 1 : 0)
  end  
end
