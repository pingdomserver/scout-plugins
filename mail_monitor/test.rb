require File.dirname(__FILE__) + "/../test_helper.rb"
require File.dirname(__FILE__) + "/mail_monitor.rb"

class MailMonitorTest < Test::Unit::TestCase

  def setup
    @plugin = MailMonitor.new(nil, {}, {:mail_binary => "postqueue,sendmail,mailq"})
  end

  def test_successful_run_with_no_errors
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/empty.txt')
    })

    res = @plugin.run()
    assert(res[:errors].empty?, "res[:errors] is not empty")
  end

  def test_unable_to_find_mail_bin
    @plugin.stubs(:mail_binary).returns(nil)

    res = @plugin.run()
    assert_equal res[:errors].first[:subject], "mail binary cannot be found for postqueue, sendmail, mailq"
  end

  def test_failed_run_with_errors
    @plugin.stubs(:execute_command).returns({
      :exit_code => 69,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/fatal.txt')
    })

    res = @plugin.run()
    assert_equal res[:errors].first[:subject], "Bad exit code from '/usr/sbin/postqueue -p'"
    assert_equal res[:errors].first[:body], "postqueue: fatal: Queue report unavailable - mail system is down"
  end

  def test_0_messages
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/empty.txt')
    })

    res = @plugin.run()
    assert_equal 0, res[:reports].first[:total]
    assert_equal 0, res[:reports].first[:active]
    assert_equal 0, res[:reports].first[:hold]
    assert_equal 0, res[:reports].first[:deferred]
  end

  def test_more_than_0_messages
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/more_than_one_message.txt')
    })

    res = @plugin.run()
    assert_equal 2, res[:reports].first[:total]
    assert_equal 0, res[:reports].first[:active]
    assert_equal 0, res[:reports].first[:hold]
    assert_equal 2, res[:reports].first[:deferred]
  end

  def test_more_than_0_messages_with_queue_indicators
    @plugin.stubs(:execute_command).returns({
      :exit_code => 0,
      :output => File.read(File.dirname(__FILE__)+'/fixtures/more_than_one_with_queue_indicator.txt')
    })

    res = @plugin.run()
    assert_equal 6, res[:reports].first[:total]
    assert_equal 3, res[:reports].first[:active]
    assert_equal 1, res[:reports].first[:hold]
    assert_equal 2, res[:reports].first[:deferred]
  end
end
