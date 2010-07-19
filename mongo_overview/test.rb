require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/mongo_overview"
require 'mongo'

class MongoOverviewTest < Test::Unit::TestCase
  
  def setup
    @options=parse_defaults("mongo_stats")
    Mongo::Connection.any_instance.stubs(:initialize).returns(Mongo::DB.new('localhost','27017'))
  end
  
  def test_should_error_without_yaml_file
    plugin=MongoOverview.new(nil,{},@options)
    res=plugin.run
    assert res[:errors].first[:subject] =~ /not provided/
  end
  
  def test_should_error_with_invalid_yaml_path
    plugin=MongoOverview.new(nil,{},@options.merge({:path_to_db_yml => 'invalid'}))
    res=plugin.run
    assert res[:errors].first[:subject] =~ /Unable to find/
  end
  
  def test_should_parse_stats    
    opts = @options.merge({:path_to_db_yml => File.dirname(__FILE__)+'/fixtures/database.yml'})
    plugin=MongoOverview.new(nil,{},opts)
    Mongo::DB.any_instance.stubs(:stats).returns(STATS)
    Mongo::DB.any_instance.stubs(:command).with('serverStatus' => 1).returns(SERVER_STATUS)
    
    # 10 minutes in the past
    time = Time.now
    Timecop.travel(time-60*10) do     
      res=plugin.run
      assert_equal STATS['objects'], res[:reports].find { |r| r.keys.include?(:objects)}[:objects]
      assert_nil res[:reports].find { |r| r.keys.include?(:btree_miss_ratio)}
      first_run_memory = res[:memory]    
      assert_equal SERVER_STATUS['globalLock']['totalTime'], 
                   first_run_memory[:global_lock_total_time]
    
      # 2nd run, 10 minutes later, to test counters. 
      Timecop.travel(time) do 
        Mongo::DB.any_instance.stubs(:command).with('serverStatus' => 1).returns(SERVER_STATUS_2ND_RUN)
        plugin=MongoOverview.new(time-60*10,first_run_memory,opts)
        res=plugin.run()
        
        # check the global_lock_ratio
        assert_equal 10.0/100.0, 
                     res[:reports].find { |r| r.keys.include?(:global_lock_ratio)}[:global_lock_ratio]
      
        # check btree hit ratio
        assert_equal 0.1, res[:reports].find { |r| r.keys.include?(:btree_miss_ratio)}[:btree_miss_ratio]
        
        # check rate for btree hits
        assert_in_delta 10.0/(10*60), 
                           res[:reports].find { |r| r.keys.include?(:btree_hits)}[:btree_hits], 0.001        
      end # timecop
    end
  
  end
  
  def test_should_parse_stats_if_no_change    
    opts = @options.merge({:path_to_db_yml => File.dirname(__FILE__)+'/fixtures/database.yml'})
    plugin=MongoOverview.new(nil,{},opts)
    Mongo::DB.any_instance.stubs(:stats).returns(STATS)
    Mongo::DB.any_instance.stubs(:command).with('serverStatus' => 1).returns(SERVER_STATUS)
    
    # 10 minutes in the past
    time = Time.now
    Timecop.travel(time-60*10) do     
      res=plugin.run
      assert_equal STATS['objects'], res[:reports].find { |r| r.keys.include?(:objects)}[:objects]
      assert_nil res[:reports].find { |r| r.keys.include?(:btree_miss_ratio)}
      first_run_memory = res[:memory]    
      assert_equal SERVER_STATUS['globalLock']['totalTime'], 
                   first_run_memory[:global_lock_total_time]
    
      # 2nd run, 10 minutes later, to test counters. 
      Timecop.travel(time) do 
        Mongo::DB.any_instance.stubs(:command).with('serverStatus' => 1).returns(SERVER_STATUS)
        plugin=MongoOverview.new(time-60*10,first_run_memory,opts)
        res=plugin.run()
        
        # check the global_lock_ratio
        assert_nil res[:reports].find { |r| r.keys.include?(:global_lock_ratio)}
      
        # check btree hit ratio
        assert_nil res[:reports].find { |r| r.keys.include?(:btree_miss_ratio)}
        
        # check rate for btree hits
        assert_in_delta 0, res[:reports].find { |r| r.keys.include?(:btree_hits)}[:btree_hits], 0.001
      end # timecop
    end
  end
  
  STATS = {"collections"=>2, "objects"=>200, "dataSize"=>92, "storageSize"=>5632, "numExtents"=>2, 
    "indexes"=>1, "indexSize"=>8192, "ok"=>1.0}
    
  SERVER_STATUS = {"version"=>"1.4.4", "uptime"=>31.0, 
    "localTime"=>Time.parse('Fri Jul 16 23:24:41 UTC 2010'), 
    "globalLock"=>{"totalTime"=>100.0, "lockTime"=>10.0, "ratio"=>1.27127657280181e-05}, 
    "mem"=>{"bits"=>64, "resident"=>2, "virtual"=>2643, "supported"=>true, "mapped"=>0}, 
    "connections"=>{"current"=>1, "available"=>19999}, "extra_info"=>{"note"=>"fields vary by platform"}, 
    "indexCounters"=>{"btree"=>{"accesses"=>0, "hits"=>0, "misses"=>0, "resets"=>0, "missRatio"=>0.0}}, 
    "backgroundFlushing"=>{"flushes"=>0, "total_ms"=>0, "average_ms"=>0.0, "last_ms"=>0, 
    "last_finished"=>Time.parse('Thu Jan 01 00:00:00 UTC 1970')}, 
    "opcounters"=>{"insert"=>0, "query"=>1, "update"=>0, "delete"=>0, "getmore"=>0, "command"=>2}, 
    "asserts"=>{"regular"=>0, "warning"=>0, "msg"=>0, "user"=>0, "rollovers"=>0}, "ok"=>1.0}
    
  SERVER_STATUS_2ND_RUN = {"version"=>"1.4.4", "uptime"=>31.0, 
  "localTime"=>Time.parse('Fri Jul 16 23:34:41 UTC 2010'), 
  "globalLock"=>{"totalTime"=>200.0, "lockTime"=>20.0, "ratio"=>1.27127657280181e-05}, 
  "mem"=>{"bits"=>64, "resident"=>2, "virtual"=>2643, "supported"=>true, "mapped"=>0}, 
  "connections"=>{"current"=>1, "available"=>19999}, "extra_info"=>{"note"=>"fields vary by platform"}, 
  "indexCounters"=>{"btree"=>{"accesses"=>0, "hits"=>10, "misses"=>1, "resets"=>0, "missRatio"=>0.0}}, 
  "backgroundFlushing"=>{"flushes"=>0, "total_ms"=>0, "average_ms"=>0.0, "last_ms"=>0, 
  "last_finished"=>Time.parse('Thu Jan 01 00:00:00 UTC 1970')}, 
  "opcounters"=>{"insert"=>0, "query"=>1, "update"=>0, "delete"=>0, "getmore"=>0, "command"=>2}, 
  "asserts"=>{"regular"=>0, "warning"=>0, "msg"=>0, "user"=>0, "rollovers"=>0}, "ok"=>1.0}
end