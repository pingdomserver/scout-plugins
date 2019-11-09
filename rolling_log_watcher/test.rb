require 'test/unit'
require 'rubygems'
require 'scout'
require 'tempfile'
require File.dirname(__FILE__)+'/rolling_log_watcher'

class RollingLogWatcherTest < Test::Unit::TestCase
  def setup
    @log_file = File.dirname(__FILE__)+'/system.log'
    @grep_args = '-E "^([[:alnum:]]|\.)*Exception"'

    `rm #{@log_file}`
  end

  def test_no_roll
    memory = {}
    options = {'log_path' => @log_file, 'grep_args' => @grep_args}

    append_log_content()

    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result)

    # Scanning original content; expect one occurrence
    memory = result[:memory]
    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result, [:occurrences => 1])

    # No new log content; expect no occurrences
    memory = result[:memory]
    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result, [:occurrences => 0])

    # Scan net new content; expect one occurrence
    append_log_content()
    memory = result[:memory]
    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result, [:occurrences => 1])

    # Simulate log file rollover; no replacement file yet
    append_log_content()
    `mv #{@log_file} #{@log_file}.1`

    memory = result[:memory]
    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result, [:occurrences => 1])

    # Scan content in replacement file; expect one occurrence
    append_log_content()
    memory = result[:memory]
    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result, [:occurrences => 1])

    # Log file rolled; original has new content (one occurrence).
    # New log file has new content (one occurrence).
    # Expect two occurrences.
    append_log_content()
    `mv #{@log_file} #{@log_file}.1`
    append_log_content()

    memory = result[:memory]
    result = RollingLogWatcher.new(nil, memory, options).run
    check_result(result, [:occurrences => 2])
  end

  def append_log_content()
    File.open(@log_file, 'a') do |f|
      f.puts('My test content.')
      f.puts('An Exception with pre-space.')
      f.puts('An.Exception without pre-space.')
    end
  end

  def check_result(result, reports=[])
    puts result.inspect

    assert_not_nil(result[:memory][:last_inode], "memory missing key: last_inode")

    assert_equal(reports, result[:reports], 'reports not equal')
    assert(result[:errors].empty?, 'errors not empty: ' + result[:errors].inspect)
    assert(result[:alerts].empty?, 'alerts not empty: ' + result[:alerts].inspect)
  end
end
