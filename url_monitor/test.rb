require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../url_monitor.rb', __FILE__)

require 'open-uri'
class UrlMonitorTest < Test::Unit::TestCase

  DEFAULT_OPTIONS = {:valid_http_status_codes =>'200',:check_ssl=>'yes',:body_content=>'.*'}

  def setup
  end

  def teardown
    FakeWeb.clean_registry
  end

  def url_mon options
    UrlMonitor.new(nil,{},DEFAULT_OPTIONS.merge(options))
  end

  def test_initial_run
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page",:status => ["200", "OK"])
    @plugin=url_mon({:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is responding/
  end

  def test_404
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page", :status => ["404", "Not Found"])
    @plugin=url_mon({:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is not responding/
  end


  def test_500
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page", :status => ["500", "Error"])
    @plugin=url_mon({:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is not responding/
  end

  def test_200
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page", :status => ["200", "OK"])
    @plugin=url_mon({:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
  end

  def test_202
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "the page", :status => ["200", "OK"])
    @plugin=url_mon({:url=>uri,:valid_http_status_codes=>'2.*'})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
  end

  def test_bad_host
    uri="http://fake"
    @plugin=url_mon({:url=>uri})
    res = @plugin.run()
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is not responding/
    assert res[:alerts].first[:body] =~ /Message: getaddrinfo: nodename nor servname provided, or not known/
  end

  def test_valid_ssl_cert
    uri="https://google.com"
    @plugin=url_mon({:url=>uri,:valid_http_status_codes=>'3.*'})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
  end

  def test_invalid_ssl_cert
    uri="https://google.com"
    @plugin=url_mon({:host_override=>'localhost',:url=>uri,:valid_http_status_codes=>'3.*'})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
    assert res[:alerts].first[:subject] =~ /is not responding/
    assert res[:alerts].first[:body] =~ /Message: Connection refused/
  end

  def test_invalid_ssl_cert_with_ignore
    uri="https://74.125.233.69" #Google ip
    @plugin=url_mon({:check_ssl=>'no',:url=>uri})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
  end

  def test_200_regex
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "OK", :status => ["200", "OK"])
    @plugin=url_mon({:url=>uri,:body_content=>'OK'})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 1, res[:reports].find { |r| r.has_key?(:up)}[:up]
  end


  def test_200_regex_invalid
    uri="http://scoutapp.com"
    FakeWeb.register_uri(:head, uri, :body => "error", :status => ["200", "OK"])
    @plugin=url_mon({:url=>uri,:body_content=>'OK'})
    res = @plugin.run()
    assert res[:reports].any?
    assert_equal 0, res[:reports].find { |r| r.has_key?(:up)}[:up]
  end
end
