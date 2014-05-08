require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../rails_requests.rb', __FILE__)


class RailsRequestsTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("rails_requests")
    @log = File.dirname(__FILE__)+"/log/production_rails_2_3.log"
    @rails3_log = File.dirname(__FILE__)+"/log/production_rails_3_0.log"
    @rails4_log = File.dirname(__FILE__)+"/log/production_rails_4_1.log"
    @rails2_oink_log = File.dirname(__FILE__)+"/log/production_rails_oink_2_2.log"
  end

  def test_run_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :rails_version => '2'))
    res=plugin.run
    assert_equal 0.0, res[:reports].first[:slow_requests_percentage]
    assert_equal "0.36", res[:reports].first[:average_request_length]
    assert_equal "0.30", res[:reports].first[:average_db_time]
    assert_equal "0.04", res[:reports].first[:average_view_time]
    assert_equal 1, res[:summaries].size
  end
  
  def test_run_oink_rails_2_2
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-06-18 11:27:15")},@options.merge(:log => @rails2_oink_log, :rails_version => '2', :max_request_length => 30))
    res=plugin.run
    assert_equal 0.0, res[:reports].first[:slow_requests_percentage]
    assert_equal "2.15", res[:reports].first[:average_request_length]
    assert_equal "2.00", res[:reports].first[:average_db_time]
    assert_equal "0.14", res[:reports].first[:average_view_time]
    assert_equal 1, res[:summaries].size
  end
  
  def test_run_with_memory_alert_oink_rails_2_2
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-06-18 11:27:15")},
    @options.merge(:log => @rails2_oink_log,:rails_version => '2',:max_request_length => 30,:max_memory_diff => '5'))
    res=plugin.run
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Memory Increase(5.0 MB) exceeded on 1 request",res[:alerts].first[:subject]
    assert_match %r(http://localhost/browse/all_subjects), res[:alerts].first[:body] 
    assert_match %r(Memory Increase: 6 MB), res[:alerts].first[:body]  end

  def test_run_with_slow_request_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :rails_version => '2', :max_request_length=>2))
    res=plugin.run
    assert_equal 10, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(2 sec) exceeded on 1 request",res[:alerts].first[:subject]
    assert_match %r(http://hotspotr.com/wifi/map/660-vancouver-canada), res[:alerts].first[:body] 
  end
  
  def test_run_with_memory_alert_and_slow_request_alert_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-06-18 11:27:15")},
    @options.merge(:log => @rails2_oink_log,:rails_version => '2',:max_request_length => 3,:max_memory_diff => '5'))
    res=plugin.run
    assert_equal 2, res[:alerts].size
  end

  def test_ignored_slow_request_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :rails_version => '2', :max_request_length=>2, :ignored_actions=>'map'))
    res=plugin.run
    assert_equal 0, res[:reports].first[:slow_requests_percentage]
    assert_equal 0, res[:alerts].size
  end

  def test_run_with_two_slow_requests_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :rails_version => '2', :max_request_length=>1))
    res=plugin.run
    assert_equal 20, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(1 sec) exceeded on 2 requests", res[:alerts].first[:subject]
    assert_equal "http://hotspotr.com/wifi\nCompleted in 1.001s (View: 0.024s, DB: 0.9s) | Status: 200\n\nhttp://hotspotr.com/wifi/map/660-vancouver-canada\nCompleted in 2.1s (View: 0.1s, DB: 2.0s) | Status: 200\n\n",
                  res[:alerts].first[:body]
  end

  def test_run_rails_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails3_log, :rails_version => '3'))
    res=plugin.run
    assert_equal "0.39", res[:reports].first[:average_request_length]
    assert_equal "0.02", res[:reports].first[:average_db_time]   # NOTE: the Rails3 Parser doesn't extract these values 4/30/2010
    assert_equal "0.35", res[:reports].first[:average_view_time] # NOTE: the Rails3 Parser doesn't extract these values 4/30/2010
  end

  def test_run_with_slow_request_rails_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails3_log, :max_request_length=>2, :rails_version => '3'))
    res=plugin.run
    assert_equal 10, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(2 sec) exceeded on 1 request",res[:alerts].first[:subject]
    assert_equal "/home\nCompleted in 2.1s (View: 1.9s, DB: 0.1s) | Status: 200\n\n", res[:alerts].first[:body]
  end

  def test_ignored_slow_request_rails_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails3_log, :max_request_length=>2, :ignored_actions=>'home', :rails_version => '3'))
    res=plugin.run
    assert_equal 0, res[:reports].first[:slow_requests_percentage]
    assert_equal 0, res[:alerts].size
  end

  def test_run_rails_4
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails4_log))
    res=plugin.run
    assert_equal "1.31", res[:reports].first[:average_request_length]
    assert_equal "0.02", res[:reports].first[:average_db_time]
    assert_equal "0.21", res[:reports].first[:average_view_time] 
  end

  def test_run_with_slow_request_rails_4
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails4_log, :max_request_length=>2))
    res=plugin.run
    assert_equal 10, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(2 sec) exceeded on 1 request",res[:alerts].first[:subject]
    assert_equal "/home\nCompleted in 6.0s (View: 2.1s, DB: 0.2s) | Status: 200\n\n", res[:alerts].first[:body]
  end

  def test_ignored_slow_request_rails_4
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails4_log, :max_request_length=>2, :ignored_actions=>'home'))
    res=plugin.run
    assert_equal 0, res[:reports].first[:slow_requests_percentage]
    assert_equal 0, res[:alerts].size
  end

  def test_wrong_log_path
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => "BOGUS"))
    res=plugin.run
    assert_equal 1, res[:errors].size
    assert_match /Unable to find the Rails log file/, res[:errors].first[:subject]
  end

  def test_empty_log_file
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},
                             @options.merge(:log =>  File.dirname(__FILE__)+"/log/empty.log"))
    res=plugin.run
    assert_equal 0, res[:errors].size, res.to_yaml
    assert_equal 0, res[:alerts].size
  end

end