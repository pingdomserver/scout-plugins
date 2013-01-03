require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mysql_replication_monitor.rb', __FILE__)

require 'mysql'

class MysqlReplicationMonitorTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("mysql_replication_monitor")
  end

  def test_replication_success
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin = MysqlReplicationMonitor.new(nil, {}, @options)
    ms_res = Mysql::Result.new
    ms_res.stubs(:fetch_hash).returns(FIXTURES[:success])
    Mysql.any_instance.stubs(:query).with("show slave status").returns(ms_res).once
    res = @plugin.run()

    # assertions
    assert_equal 1, res[:reports].first['Seconds Behind Master']
  end

  def test_replication_not_configured
    @plugin = MysqlReplicationMonitor.new(nil, {}, @options)
    ms_res = Mysql::Result.new
    ms_res.stubs(:fetch_hash).returns(nil)
    Mysql.any_instance.stubs(:query).with("show slave status").returns(ms_res).once
    res= @plugin.run()

    # assertions
    assert_equal 1, res[:errors].size
  end

  def test_replication_failure
    @plugin = MysqlReplicationMonitor.new(nil, {}, @options)
    ms_res = Mysql::Result.new
    ms_res.stubs(:fetch_hash).returns(FIXTURES[:failure])
    Mysql.any_instance.stubs(:query).with("show slave status").returns(ms_res).once
    res = @plugin.run()

    # assertions
    assert_equal 1, res[:alerts].size
    assert_equal 1, res[:reports].first['Seconds Behind Master']
  end

  def test_replication_failure_nil_seconds_behind
    @plugin = MysqlReplicationMonitor.new(nil, {}, @options)
    ms_res = Mysql::Result.new
    ms_res.stubs(:fetch_hash).returns(FIXTURES[:failure_nil_seconds_behind])
    Mysql.any_instance.stubs(:query).with("show slave status").returns(ms_res).once
    res = @plugin.run()

    # assertions
    assert_equal 1, res[:alerts].size
  end

  FIXTURES=YAML.load(<<-EOS)
    :success:
      Slave_IO_Running: 'Yes'
      Slave_SQL_Running: 'Yes'
      Seconds_Behind_Master: 1
    :failure:
      Slave_IO_Running: 'Yes'
      Slave_SQL_Running: 'No'
      Seconds_Behind_Master: 1
    :failure_nil_seconds_behind:
      Slave_IO_Running: 'Yes'
      Slave_SQL_Running: 'Yes'
      Seconds_Behind_Master: NULL
    :full:
      Slave_IO_State: Waiting for master to send event
      Master_Host: mysql002.int
      Master_User: replication
      Master_Port: 3306
      Connect_Retry: 60
      Master_Log_File: mysql-bin.000006
      Read_Master_Log_Pos: 505440314
      Relay_Log_File: slave100-relay.000068
      Relay_Log_Pos: 505440459
      Relay_Master_Log_File: mysql-bin.000006
      Slave_IO_Running: 'Yes'
      Slave_SQL_Running: 'Yes'
      Replicate_Do_DB:
      Replicate_Ignore_DB:
      Replicate_Do_Table:
      Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
      Replicate_Wild_Ignore_Table:
      Last_Errno: 0
      Last_Error:
      Skip_Counter: 0
      Exec_Master_Log_Pos: 505440314
      Relay_Log_Space: 505440656
      Until_Condition: None
      Until_Log_File:
      Until_Log_Pos: 0
      Master_SSL_Allowed: 'No'
      Master_SSL_CA_File:
      Master_SSL_CA_Path:
      Master_SSL_Cert:
      Master_SSL_Cipher:
      Master_SSL_Key:
      Seconds_Behind_Master: 1
      Master_SSL_Verify_Server_Cert: 'No'
      Last_IO_Errno: 0
      Last_IO_Error:
      Last_SQL_Errno: 0
      Last_SQL_Error:
  EOS

end
