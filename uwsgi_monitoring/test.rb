require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../uwsgi_monitoring.rb', __FILE__)

require 'open-uri'
class UWSGIMonitoringTest < Test::Unit::TestCase

  def teardown
    FakeWeb.clean_registry
  end

  def test_should_report
    url = '127.0.0.1:1717'
    body = File.read(File.dirname(__FILE__) + '/fixtures/output.json')
    data = JSON.parse(body)
    
    @plugin = UWSGIMonitoring.new(nil, {}, {:location => url})
    res = @plugin.process_uwsgi_stats(data)
    stats = res.first
    assert_equal 2, stats[:workers]
    assert_equal 171, stats[:avg_rt]
    assert_equal 252, stats[:rss]
    assert_equal 1065, stats[:vsz]
  end
  
end
