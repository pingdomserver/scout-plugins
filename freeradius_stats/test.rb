require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../freeradius_stats.rb', __FILE__)

class FreeradiusStatsTest < Test::Unit::TestCase

  def setup
    @options = parse_defaults("freeradius_stats")
  end

  def teardown
  end

  def test_clean_run
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=FreeradiusStats.new(nil,{},@options)
    @plugin.returns(FIXTURES[:stats]).once
    res = @plugin.run()

    # assertions
    assert res[:alerts].empty?
    assert res[:errors].empty?
  end

  def test_alert
    @plugin=FreeradiusStats.new(nil,{},@options)
    @plugin.returns(FIXTURES[:stats_alert]).once
    res = @plugin.run()
    
    # assertions
    assert_equal 1, res[:alerts].size
    assert res[:errors].empty?
  end

  FIXTURES=YAML.load(<<-EOS)
    :stats: |
      Received response ID 230, code 2, length = 140
        FreeRADIUS-Total-Access-Requests = 21287
        FreeRADIUS-Total-Access-Accepts = 20677
        FreeRADIUS-Total-Access-Rejects = 677
        FreeRADIUS-Total-Access-Challenges = 0
        FreeRADIUS-Total-Auth-Responses = 21354
        FreeRADIUS-Total-Auth-Duplicate-Requests = 0
        FreeRADIUS-Total-Auth-Malformed-Requests = 0
        FreeRADIUS-Total-Auth-Invalid-Requests = 0
        FreeRADIUS-Total-Auth-Dropped-Requests = 0
        FreeRADIUS-Total-Auth-Unknown-Types = 0
    :stats_alert: |
      radclient: no response from server for ID 15 socket 3
  EOS

end