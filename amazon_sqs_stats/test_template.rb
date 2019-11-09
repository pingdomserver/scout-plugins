# Template for a unit test of the amazon_sqs_stats plugin for Scout.
#
# Requires an AWS account with access to SQS.  Edit the source.
#
# This test creates a queue.
#
# Steve Ims (steve_ims@yahoo.com)

require 'test/unit'
require 'rubygems'
require 'scout'
require 'aws-sdk'
require File.dirname(__FILE__)+'/amazon_sqs_stats'

class AmazonSqsStatsTest < Test::Unit::TestCase
  def setup
    # Required values.
    @access_key = 'ACCESS_KEY'
    @secret_key = 'SECRET_KEY'
    @queue = 'QUEUE_NAME'

    sqs = AWS::SQS.new(
      :access_key_id => @access_key,
      :secret_access_key => @secret_key)

    @q = sqs.queues.create(@queue)
  end

  def teardown
    @q.delete()
  end

  def test_it
    memory = {}
    options = {
      'access_key' => @access_key,
      'secret_key' => @secret_key,
      'queue' => @queue
    }

    result = AmazonSqsStats.new( nil, memory, options ).run
    check_result( result, ['Messages Ready' => 0, 'Messages Unacked' => 0] )

    msg_1 = 'Test message 1.'
    @q.send_message( msg_1 )

    sleep( 30 )  # Allow stats to settle

    result = AmazonSqsStats.new( nil, memory, options ).run
    check_result( result, ['Messages Ready' => 1, 'Messages Unacked' => 0] )

    message = @q.receive_message( :visibility_timeout => 120 )
    assert_equal( message.body, msg_1, 'Message body not matched.' )

    sleep( 30 )  # Allow stats to settle

    result = AmazonSqsStats.new( nil, memory, options ).run
    check_result( result, ['Messages Ready' => 0, 'Messages Unacked' => 1] )

    message.delete()
    sleep( 30 )  # Allow stats to settle

    result = AmazonSqsStats.new( nil, memory, options ).run
    check_result( result, ['Messages Ready' => 0, 'Messages Unacked' => 0] )
  end

  def check_result(result, reports=[])
    puts result.inspect

    assert_equal(reports, result[:reports], 'reports not equal')
    assert(result[:errors].empty?, 'errors not empty: ' + result[:errors].inspect)
    assert(result[:alerts].empty?, 'alerts not empty: ' + result[:alerts].inspect)
  end
end
