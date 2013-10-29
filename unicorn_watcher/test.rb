require File.dirname(__FILE__)+"/unicorn_watcher"
require 'test/unit'
require "mocha/setup"

class UnicornWatcherTest < Test::Unit::TestCase

  def test_report_no_pid
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    result = plugin.run
    assert_equal result[:reports][0][:unicorn_master_count], 0, "PID does not exist"
  end

  def test_report_with_pid
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("99")
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    plugin.stubs(:is_running?).returns(true)
    result = plugin.run
    assert_equal result[:reports][0][:unicorn_master_count], 1, "PID exists"
  end

  def test_trigger_alert
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    plugin.expects(:alert)
    result = plugin.run
  end

  def test_trigger_no_alert
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("99")
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    plugin.stubs(:is_running?).returns(true)
    plugin.expects(:alert).never
    result = plugin.run
  end

  def test_wrong_process_name
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("99")
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    plugin.stubs(:`).returns("some other process with 99")
    plugin.expects(:alert)
    plugin.run
  end

  def test_wrong_pid_name
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("99")
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    plugin.stubs(:`).returns("unicorn_master")
    plugin.expects(:alert)
    plugin.run
  end

  def test_valid_process_and_pid
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("99")
    plugin = UnicornWatcher.new(nil, {}, {:directory => "/foo/bar", :process_name => "unicorn_master"})
    plugin.stubs(:`).returns("unicorn_master 99")
    plugin.expects(:alert).never
    plugin.run
  end

end