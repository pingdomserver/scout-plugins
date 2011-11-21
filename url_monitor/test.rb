require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../url_monitor.rb', __FILE__)

require 'open-uri'
class UrlMonitorTest < Test::Unit::TestCase
  def setup
  end

  def teardown
    FakeWeb.clean_registry
  end

  def test_initial_run
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page")
    @plugin=UrlMonitor.new(nil,{},{:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is responding/
  end

  def test_404
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page", :status => ["404", "Not Found"])
    @plugin=UrlMonitor.new(nil,{},{:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is not responding/
  end

  def test_bad_host
    uri="http://fake"
    @plugin=UrlMonitor.new(nil,{},{:url=>uri})
    res = @plugin.run()
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is not responding/
    assert res[:alerts].first[:body] =~ /Message: getaddrinfo: nodename nor servname provided, or not known/
  end
end
