require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mysql_thread_pool_monitor.rb', __FILE__)

require 'mysql'

class MysqlThreadPoolMonitorTest < Test::Unit::TestCase

  def setup
    @options = parse_defaults("mysql_thread_pool_monitor")
  end

  # Tests that if the plugin is able to connect, and process the SELECT_THREAD_GROUP_STATS no errors are returned
  def test_connect
    ms_res = Mysql::Result.new
    ms_res.stubs(:fetch_hash).returns({}, nil)
    mock_mysql_connection.stubs(:query).with(MysqlThreadPoolMonitor::SELECT_THREAD_GROUP_STATS).returns(ms_res).once
    plugin = MysqlThreadPoolMonitor.new(nil, memory = {}, @options)
    result = plugin.run
    assert result.is_a?(Hash)
    assert_equal 0, result[:errors].length, "number of errors"
  end

  # Tests the connection failure error in the event that mysql is not running, or the plugin is mis-configured
  def test_connect_fail
    fake_mysql_connect_exception = Mysql::Error.new("Can't connect to MySQL server on '127.0.0.1' (61)")
    Mysql.stubs(:new).raises(fake_mysql_connect_exception)
    plugin = MysqlThreadPoolMonitor.new(nil, memory = {}, @options)
    result = plugin.run
    assert result.is_a?(Hash)
    assert_equal 1, result[:errors].length, "number of errors"
    assert_equal "Unable to connect to MySQL", result[:errors][0][:subject], "Error subject"
  end

  # Tests the missing tp_thread_group_stats table in the  event that the thread_pool plugin is not loaded
  def test_thread_pool_plugin_not_installed
    fake_mysql_unknown_table_exception = Mysql::Error.new("Unknown table 'tp_thread_group_stats' in information_schema")
    mock_mysql = mock_mysql_connection
    mock_mysql.stubs(:query).with(MysqlThreadPoolMonitor::SELECT_THREAD_GROUP_STATS).raises(fake_mysql_unknown_table_exception)
    plugin = MysqlThreadPoolMonitor.new(nil, memory = {}, @options)
    result = plugin.run
    assert result.is_a?(Hash)
    assert_equal 1, result[:errors].length, "number of errors"
    assert_equal "MySQL thread pool plugin not installed", result[:errors][0][:subject], "Error subject"
  end

  # Tests the expected return value from the fixture is in the expected Array of Hashes format
  def test_thread_group_stats_fixture
    fake_result_set = create_thread_group_stats_fixture(0, 0)
    headers = %w{TP_GROUP_ID CONNECTIONS_STARTED CONNECTIONS_CLOSED QUERIES_EXECUTED QUERIES_QUEUED THREADS_STARTED PRIO_KICKUPS STALLED_QUERIES_EXECUTED BECOME_CONSUMER_THREAD BECOME_RESERVE_THREAD BECOME_WAITING_THREAD WAKE_THREAD_STALL_CHECKER SLEEP_WAITS DISK_IO_WAITS ROW_LOCK_WAITS GLOBAL_LOCK_WAITS META_DATA_LOCK_WAITS TABLE_LOCK_WAITS USER_LOCK_WAITS BINLOG_WAITS GROUP_COMMIT_WAITS FSYNC_WAITS}
    values = %w{0 4265 4246 206888317 118563783 23 0 16696 5726735 904472 138759896 21719 0 6616163 214 0 0 234 0 0 0 0}
    first_fake_result = fake_result_set.shift
    headers.each_with_index { |header, i|
      assert_equal values[i].to_i, first_fake_result[header]
    }
  end

  # Tests the functionality of the plugin, that it reports rate-of-change using the plugin :counter api, and that the desired fields are included in the plugins output
  def test_plugin_averages_rate_of_change_for_all_important_counters
    ms_res = Mysql::Result.new
    min_rate = 0.0
    max_rate = 10.0
    ms_res.stubs(:fetch_hash).returns(*create_thread_group_stats_fixture(0, 0))
    ms_res.stubs(:fetch_hash).returns(*create_thread_group_stats_fixture(min_rate, max_rate))
    ms_res.stubs(:fetch_hash).returns(nil)
    mock_mysql_connection.stubs(:query).with(MysqlThreadPoolMonitor::SELECT_THREAD_GROUP_STATS).returns(ms_res)
    last_run = Time.now
    plugin_first_run = MysqlThreadPoolMonitor.new(nil, memory = {}, @options)
    result_one = plugin_first_run.run
    assert result_one[:reports].length == 0
    Timecop.travel(last_run + 60) do
      plugin_second_run = MysqlThreadPoolMonitor.new(last_run, result_one[:memory], @options)
      result_two = plugin_second_run.run
      MysqlThreadPoolMonitor::HEADERS_TO_TRACK_RATE_OF.each { |tracked_header|
        report_key_avg = "#{tracked_header.downcase}_rate_avg"
        result_two[:reports].each { |report|
          if report[report_key_avg] then
            assert_equal 5.0, report[report_key_avg], report_key_avg + " " + report.inspect
          end
        }
      }
    end
  end

private

  # Mock out the database connection
  def mock_mysql_connection
    fake_mysql = mock
    Mysql.stubs(:new).returns(fake_mysql)
    return fake_mysql
  end

  # Returns an Array of Hashes for the combined result set from the SELECT_THREAD_GROUP_STATS statement
  def create_thread_group_stats_fixture(increment_min, increment_max)
    lines = File.readlines("fixture_thread_group_stats.tsv")
    headers = lines.shift.strip.split("\t")
    used_inc_min = false
    used_inc_max = false
    result_set = []
    lines.each { |line|
      if not used_inc_min then
        increment = increment_min
        used_inc_min = true
      elsif not used_inc_max then
        increment = increment_max
        used_inc_max = true
      else
        increment = ((increment_min.to_f + increment_max.to_f) / 2.0).to_i
      end
      result = {}
      stripped_line = line.strip
      columns = stripped_line.split("\t")
      headers.each { |header|
        result[header] = columns.shift.to_i + increment
      }
      result_set << result
    }
    result_set
  end

end
