require File.dirname(__FILE__) + "/../test_helper.rb"
require File.dirname(__FILE__) + "/cassandra.rb"

class CassandraTest < Test::Unit::TestCase

  def setup
    @plugin = Cassandra.new(nil, {}, {:nodetool_path => "/usr/bin/nodetool"})
  end

  def test_successful_run_with_no_errors
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/successful-1dc-7nodes.txt')
    })

    res = @plugin.run()
    assert(res[:errors].empty?, "res[:errors] is not empty")
    assert(res[:alerts].empty?, "res[:alerts] is not empty")
  end

  def test_unable_to_find_nodetool
    File.stubs(:exist?).with('/usr/bin/nodetool').returns(false).once

    res = @plugin.run()
    assert_equal res[:alerts].first[:subject], "Cannot find Cassandra nodetool binary"
    assert_equal res[:alerts].first[:body], "/usr/bin/nodetool"
  end

  def test_failed_run_with_errors
    @plugin.stubs(:execute_command).returns({
      :exit_code => 1,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/connection_refused.txt')
    })

    res = @plugin.run()
    assert_equal res[:alerts].first[:subject], "Unable to connect to Cassandra"
    assert_equal res[:alerts].first[:body], "Failed to connect to '127.0.0.1:7199': Connection refused"
  end

  def test_1_dc_7_nodes
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/successful-1dc-7nodes.txt')
    })

    res = @plugin.run()
    assert_equal 1, res[:reports].first[:total_datacenters]
    assert_equal 7, res[:reports].first[:total_nodes]
    assert_equal 10093, res[:reports].first[:avg_node_load]
    assert_equal 7, res[:reports].first[:up_nodes]
    assert_equal 0, res[:reports].first[:down_nodes]
  end

  def test_2_dcs_6_nodes
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/successful-2dcs-6nodes.txt')
    })

    res = @plugin.run()
    assert_equal 2, res[:reports].first[:total_datacenters]
    assert_equal 6, res[:reports].first[:total_nodes]
    assert_equal 6258125264, res[:reports].first[:avg_node_load]
    assert_equal 4, res[:reports].first[:up_nodes]
    assert_equal 2, res[:reports].first[:down_nodes]
  end
end
