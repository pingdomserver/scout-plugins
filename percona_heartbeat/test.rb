require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/percona_heartbeat"

class PerconaHeartbeatTest < Test::Unit::TestCase

  def setup
    @option = parse_defaults('percona_heartbeat')
    @plugin = PerconaHeartbeat.new({},{}, @option)
  end

  def test_binary_exists_true
    @plugin.stubs(:pt_heartbeat_binary_exists?).returns(true)
    assert @plugin.pt_heartbeat_binary_exists?
  end

  def test_binary_exists_false
    @plugin.stubs(:pt_heartbeat_binary_exists?).returns(false)
    refute @plugin.pt_heartbeat_binary_exists?
  end

  def test_config_exists_true
    @plugin.stubs(:pt_heartbeat_config_exists?).returns(true)
    assert @plugin.pt_heartbeat_config_exists?
  end

  def test_config_exists_false
    @plugin.stubs(:pt_heartbeat_config_exists?).returns(false)
    refute @plugin.pt_heartbeat_config_exists?
  end

  def test_success
    fixture_file = File.dirname(__FILE__)+"/fixtures/pt-heartbeat.output"

    @plugin.stubs(:seconds_behind_master).returns(File.read(fixture_file).to_i)
    @plugin.stubs(:pt_heartbeat_binary_exists?).returns(true)
    @plugin.stubs(:pt_heartbeat_config_exists?).returns(true)

    result = @plugin.run

    assert result[:errors].empty?
    assert result[:reports].first[:seconds_behind_master] == 1497

  end

end
