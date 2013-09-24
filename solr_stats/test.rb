require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../solr_stats.rb', __FILE__)

require 'open-uri'
class SolrStatisticsTest < Test::Unit::TestCase

  def teardown
    FakeWeb.clean_registry
  end

  def test_should_report
    uri = 'http://localhost:8983/solr/admin/mbeans'
    body = File.read(File.dirname(__FILE__) + '/fixtures/output.json')
    FakeWeb.register_uri(:get, uri + '?stats=true&wt=json', :body => body)
    
    @plugin = SolrStatistics.new(nil,{},{:location => uri, :handler => '/select'})
    res = @plugin.run()
    stats = res[:reports].first

    assert_equal 500, stats['numDocs']
    assert_equal 501, stats['maxDocs']
    assert_equal 0.0032435988363537, stats['avgRequestsPerSecond']
    assert_equal 0.074812428920417, stats['5minRateReqsPerSecond']
    assert_equal 0.14410462363288, stats['15minRateReqsPerSecond']
    assert_equal 81.741, stats['avgTimePerRequest']
    assert_equal 82.741, stats['medianRequestTime']
    assert_equal 84.741, stats['95thPcRequestTime']
  end
end
