class MongoOverview < Scout::Plugin
  OPTIONS=<<-EOS
    path_to_db_yml:
      label: Path to database.yml
    rails_env:
      label: Rails Environment
      default: production
  EOS

  needs 'mongo', 'yaml'

  def build_report 
    # check if database.yml path provided
    if option('path_to_db_yml').nil? or option('path_to_db_yml').empty?
      return error("The path to the database.yml file was not provided.","Please provide the full path to the MongoDB database file (ie - /var/www/apps/APP_NAME/current/config/database.yml)")
    end
    
    # check if database.yml loads
    begin
      yaml = YAML::load_file(option('path_to_db_yml'))
    rescue Errno::ENOENT
      return error("Unable to find the database.yml file", "Could not find a MongoDB config file at: #{option(:path_to_db_yml)}. Please ensure the path is correct.")
    end
    
    # Try to open a connection to Mongo
    config     = yaml[option('rails_env')]
    begin
      connection = Mongo::Connection.new(config['host'], config['port'])
    rescue Mongo::ConnectionFailure
      return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{config['host']}:#{config['port']}")
    end
    
    # Try to connect to the database
    @db         = connection.db(config['database'])
    begin 
      @db.authenticate(config['username'], config['password']) unless config['username'].nil?
    rescue Mongo::AuthenticationError
      return error("Unable to authenticate to MongoDB Database.",$!.message)
    end
    
    get_stats
    get_server_status
  end
  
  def get_stats
    stats = @db.stats

    report(:objects      => stats['objects'])
    report(:data_size    => stats['dataSize'])
    report(:storage_size => stats['storageSize'])
    report(:indexes      => stats['indexes'])
    report(:index_size   => stats['indexSize'])
  end
  
  def get_server_status
    stats = @db.command('serverStatus' => 1)
    counter(:btree_accesses, stats['indexCounters']['btree']['accesses'], :per => :second)
    count_and_ratio({:btree_misses => stats['indexCounters']['btree']['misses']},
                    {:btree_hits => stats['indexCounters']['btree']['hits']},
                    :btree_miss_ratio)
    counter(:btree_resets, stats['indexCounters']['btree']['resets'], :per => :second)
    lock_time = stats['globalLock']['lockTime']
    lock_total = stats['globalLock']['totalTime']
    if mem_lock_time = memory(:global_lock_lock_time) and mem_lock_total = memory(:global_lock_total_time)
      ratio = (lock_time-mem_lock_time).to_f/(lock_total-mem_lock_total).to_f
      report(:global_lock_ratio => ratio*100) unless ratio.nan?
    end
    remember(:global_lock_lock_time,lock_time)
    remember(:global_lock_total_time,lock_total)

    counter(:background_flushes_total, stats['backgroundFlushing']['flushes'], :per => :second)
    # TODO - Add back ... total ms /sec doesn't make sense. instead, remember total ms and report 
    # average as (total ms now - total ms prev) / (total now - total prev)
    # counter(:background_flushes_total_ms, stats['backgroundFlushing']['total_ms'], :per => :second)
    # counter(:background_flushes_average_ms, stats['backgroundFlushing']['average_ms'], :per => :second)
    
    # Need to stay at 19 or less metrics. The 20th will be slow query rate. Choosing not to report memory
    # data for now.
    # report(:mem_bits     => stats['mem']['bits'])      if stats['mem'] && stats['mem']['bits']
    # report(:mem_resident => stats['mem']['resident'])  if stats['mem'] && stats['mem']['resident']
    # report(:mem_virtual  => stats['mem']['virtual'])   if stats['mem'] && stats['mem']['virtual']
    # report(:mem_mapped   => stats['mem']['mapped'])    if stats['mem'] && stats['mem']['mapped']
    
    # ops
    counter(:op_inserts, stats['opcounters']['insert'], :per => :second)
    counter(:op_queries, stats['opcounters']['query'], :per => :second)
    counter(:op_updates, stats['opcounters']['update'], :per => :second)
    counter(:op_deletes, stats['opcounters']['delete'], :per => :second)
    counter(:op_get_mores, stats['opcounters']['getmore'], :per => :second)
    counter(:op_commands, stats['opcounters']['command'], :per => :second)
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