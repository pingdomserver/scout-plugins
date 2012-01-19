class MongoOverview < Scout::Plugin
  OPTIONS=<<-EOS
    path_to_db_yml:
      name: Path to database.yml
      notes: "If a database.yml file exists with MongoDB connection information, provide the full path here. Otherwise, you can enter the settings manually by clicking on the 'show advanced options' link below."
    rails_env:
      name: Rails Environment
      default: production
      notes: "If a database.yml exists, specify the Rails environment that should be used. If you aren't using a database.yml file, you can enter the settings manually by clicking on the 'show advanced options' link below."
    database:
      name: Mongo Database
      notes: Name of the MongoDB database to profile
      attributes: advanced
    host:
      name: Mongo Server
      notes: Where mongodb is running. If a database.yml file is used, the yml settings will override this.
      default: localhost
      attributes: advanced
    username:
      notes: Leave blank unless you have authentication enabled. If a database.yml file is used, the yml settings will override this.
      attributes: advanced
    password:
      notes: Leave blank unless you have authentication enabled. If a database.yml file is used, the yml settings will override this.
      attributes: advanced,password
    port:
      name: Port
      default: 27017
      notes: MongoDB standard port is 27017. If a database.yml file is used, the yml settings will override this.
      attributes: advanced
  EOS

  needs 'mongo', 'yaml'

  def build_report 
    # check if database.yml path provided
    if option('path_to_db_yml').nil?
      @db_yml = false
      # check if options provided
      @database = option('database')
      @host     = option('host') 
      @port     = option('port')
      if [@database,@host,@port].compact.size < 3
        return error("Connection settings not provided.", "Either the full path to the MongoDB database file (ie - /var/www/apps/APP_NAME/current/config/database.yml) or the database name, host, and port must be provided in the advanced settings.")
      end
      @username = option('username')
      @password = option('password')
    else
      @db_yml = true
    end
    
    # check if database.yml loads
    if @db_yml
      begin
        yaml = YAML::load_file(option('path_to_db_yml'))
      rescue Errno::ENOENT
        return error("Unable to find the database.yml file", "Could not find a MongoDB config file at: #{option(:path_to_db_yml)}. Please ensure the path is correct.")
      end
      config = yaml[option('rails_env')]
      @host     = config['host']
      @port     = config['port']
      @database = config['database']
      @username = config['username']
      @password = config['password']
    else
      
    end

    begin
      connection = Mongo::Connection.new(@host,@port,:slave_ok=>true)
    rescue Mongo::ConnectionFailure
      return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}")
    end
    
    # Try to connect to the database
    @admin_db = connection.db('admin')

    get_replica_set_status
  end
  
  def get_replica_set_status
    replset_status = @admin_db.command({'replSetGetStatus' => 1}, :check_response => false)
    return unless replset_status['ok'] == 1
    
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
    
    report(:replset_name => replset_status['set'])
    report(:replset_member_state => member_state)
    report(:replset_member_state_num => replset_status['myState'])

    primary = replset_status['members'].detect {|member| member['state'] == 1}
    if primary
      current_member = replset_status['members'].detect do |member|
        member['self']
      end
      
      if current_member
        report(:replset_replication_lag => current_member['optimeDate'] - primary['optimeDate'])
      end
    end  
    report(:replset_member_healthy => current_member['health'] ? 'True' : 'False')
  end  
end
