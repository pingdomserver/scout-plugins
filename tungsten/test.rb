require File.expand_path('../test_helper.rb')
require File.expand_path('../tungsten.rb', __FILE__)

class TungstenTest < Test::Unit::TestCase

  def setup
    @plugin = TungstenPlugin.new(nil, {}, {})
    @good_rep_roles = "\nmaster=db01\nslave=db02\n"
    # Compatible with Tungsten 1.31
    # @good_latency = "CRITICAL: db02=0.769s, db03=8.5s"
    # Compatible with Tungsten 1.32
    @good_latency = "OK: All slaves are running normally (max_latency=0.14) | db02=0.769;1800;3600;; db03=8.5;1800;3600;;"
    @good_status = "OK: All services are online\n"
    @good_datasources = <<-EOS
|Connected to manager db01:                                             |
|  web-ubuntu.dc1.datacenter.com#284555555:ONLINE                       |
|  db02.dc1.bookrenter.com#515555555:ONLINE                             |
|Connected to manager db02:                                             |
|db01(master:ONLINE, progress=472712251, VIP=(eth0:0:10.5.6.7           |
|netmask 255.255.255.0))                                                |
|  MANAGER(state=ONLINE)                                                |
|  REPLICATOR(role=master, state=ONLINE)                                |
|  DATASERVER(state=ONLINE)                                             |
|db02(slave:ONLINE, progress=472712255, latency=0.368)                  |
|  MANAGER(state=ONLINE)                                                |
|  REPLICATOR(role=slave, master=db01, state=ONLINE)                    |
|  DATASERVER(state=ONLINE)                                             |
EOS
  end

  def stub_replication_roles(plugin)
    plugin.stubs(:`).with("/opt/tungsten/cluster-home/bin/get_replicator_roles").
      returns(@good_rep_roles)
  end

  def stub_latency(plugin)
    plugin.stubs(:`).with('/opt/tungsten/cluster-home/bin/check_tungsten_latency -w 180000 -c 360000 --perfdata --perslave-perfdata').
      returns(@good_latency)
  end

  def stub_online_status(plugin)
    plugin.stubs(:`).with("/opt/tungsten/cluster-home/bin/check_tungsten_online").
      returns(@good_status)
  end

  def stub_datasources(plugin)
    plugin.stubs(:`).with('echo "ls" | /opt/tungsten/tungsten-manager/bin/cctrl').
      returns(@good_datasources)
  end

  def test_parse_datasources
    expected = { "db01" => "ONLINE", "db02" => "ONLINE" }
    assert_equal expected, @plugin.parse_datasources(@good_datasources)
  end

  def test_parse_replication_roles
    expected = { "db01" => "master", "db02" => "slave" }
    assert_equal expected, @plugin.parse_replication_roles(@good_rep_roles)
  end

  def test_parse_latency
    expected = { "db02" => 0.769, "db03" => 8.5 }
    assert_equal expected, @plugin.parse_latency(@good_latency)
  end

  def test_build_report_times_out_acceptably
    Timeout.stubs(:timeout).raises(Timeout::Error)

    result = @plugin.run
    assert_equal [], result[:alerts]
    assert_equal 1, result[:memory][:timeout]
  end

  def test_build_report_times_out_too_much
    Timeout.stubs(:timeout).raises(Timeout::Error)
    memory = {:timeout  => 4}
    @plugin = TungstenPlugin.new(nil, memory, {})

    result = @plugin.run
    expected = [{ :subject => "Tungsten plugin timed out",
                  :body => "It has timed out 5 times in a row."}]
    assert_equal expected, result[:alerts]
    assert_equal 5, result[:memory][:timeout]
  end

  def test_build_report_alerts_ok_status
    @plugin.stubs(:`).with('/opt/tungsten/cluster-home/bin/check_tungsten_online').
      returns(@good_status)
    stub_latency(@plugin)
    stub_replication_roles(@plugin)
    stub_datasources(@plugin)

    result = @plugin.run

    assert_equal [], result[:alerts]
  end

  def test_build_report_alerts_non_ok_status
    @plugin.stubs(:`).with("/opt/tungsten/cluster-home/bin/check_tungsten_online").
      returns("CRITICAL: All services are effed up\n")
    stub_latency(@plugin)
    stub_replication_roles(@plugin)
    stub_datasources(@plugin)
    result = @plugin.run

    expected = [{ :subject => "CRITICAL: All services are effed up\n",
                  :body => "CRITICAL: All services are effed up\n"}]
    assert_equal expected, result[:alerts]
  end

  def test_build_report_replication_roles_unchanged
    memory = { :replication_roles => { "db01" => "master", "db02" => "slave" }, :timeout => 0 }
    @plugin = TungstenPlugin.new(nil, memory, {})
    stub_latency(@plugin)
    stub_datasources(@plugin)
    stub_online_status(@plugin)
    @plugin.stubs(:`).with("/opt/tungsten/cluster-home/bin/get_replicator_roles").
      returns(@good_rep_roles)
    result = @plugin.run

    assert_equal [], result[:alerts]
    assert_equal memory, result[:memory] 
  end

  def test_build_report_replication_roles_changed
    memory = { :replication_roles => { "db01" => "master", "db02" => "slave" } }
    @plugin = TungstenPlugin.new(nil, memory, {})
    stub_latency(@plugin)
    stub_datasources(@plugin)
    stub_online_status(@plugin)
    @plugin.stubs(:`).with("/opt/tungsten/cluster-home/bin/get_replicator_roles").
      returns("\nslave=db01\nmaster=db02\n")
    result = @plugin.run

    assert_equal "Replication roles have changed.", result[:alerts].first[:subject]
    original_roles = result[:alerts].first[:body].split("\n\n\n").first
    new_roles = result[:alerts].first[:body].split("\n\n\n").last
    assert_match /^Formerly, roles were:/, original_roles
    assert_match /db01 acting as master/, original_roles
    assert_match /db02 acting as slave/, original_roles
    assert_match /^New roles are:/, new_roles
    assert_match /db01 acting as slave/, new_roles
    assert_match /db02 acting as master/, new_roles
    expected_memory = { :replication_roles => { "db02" => "master", "db01" => "slave" }, :timeout => 0 }
    assert_equal expected_memory, result[:memory]
  end

  def test_build_report_datasources_online
    stub_latency(@plugin)
    stub_online_status(@plugin)
    stub_replication_roles(@plugin)
    @plugin.stubs(:`).with('echo "ls" | /opt/tungsten/tungsten-manager/bin/cctrl').
      returns(@good_datasources)
    result = @plugin.run

    assert_equal [], result[:alerts]
  end

  def test_build_report_datasources_offline
    stub_latency(@plugin)
    stub_online_status(@plugin)
    stub_replication_roles(@plugin)
    @plugin.stubs(:`).with('echo "ls" | /opt/tungsten/tungsten-manager/bin/cctrl').
      returns(<<-EOS
|db01(master:ONLINE, progress=446708700, VIP=(eth0:0:10.5.6.7        |
|db02(slave:OFFLINE, progress=446708701, latency=0.775)               |
EOS
)
    result = @plugin.run

    assert_equal "db02 datasource is OFFLINE but should be ONLINE.", result[:alerts].first[:subject]
  end

  def test_build_report_dr_only_datasources_offline
    @plugin = TungstenPlugin.new(nil, {}, { :dr_only => true })
    stub_latency(@plugin)
    stub_online_status(@plugin)
    stub_replication_roles(@plugin)
    @plugin.stubs(:`).with('echo "ls" | /opt/tungsten/tungsten-manager/bin/cctrl').
      returns(<<-EOS
|db01(master:OFFLINE, progress=446708700, VIP=(eth0:0:10.5.6.7        |
|db02(slave:OFFLINE, progress=446708701, latency=0.775)               |
EOS
)
    result = @plugin.run

    assert_equal [], result[:alerts]
  end

  def test_build_report_dr_only_datasources_online
    @plugin = TungstenPlugin.new(nil, {}, { :dr_only => true })
    stub_latency(@plugin)
    stub_online_status(@plugin)
    stub_replication_roles(@plugin)
    @plugin.stubs(:`).with('echo "ls" | /opt/tungsten/tungsten-manager/bin/cctrl').
      returns(<<-EOS
|db01(master:ONLINE, progress=446708700, VIP=(eth0:0:10.5.6.7        |
|db02(slave:OFFLINE, progress=446708701, latency=0.775)               |
EOS
)
    result = @plugin.run

    assert_equal "db01 datasource is ONLINE but should be OFFLINE.", result[:alerts].first[:subject]
  end

  def test_build_report_latencies
    stub_latency(@plugin)
    stub_online_status(@plugin)
    stub_replication_roles(@plugin)
    stub_datasources(@plugin)
    result = @plugin.run

    assert_equal 0.769, result[:reports][0][:db02_latency]
    assert_equal 8.5, result[:reports][1][:db03_latency]
  end

  def test_build_report_parsing_failed
    @plugin.stubs(:`).returns("")
    result = @plugin.run

    assert_equal "Could not parse online status", result[:alerts][0][:subject]
    assert_equal "Could not parse replication roles", result[:alerts][1][:subject]
    assert_equal "Could not parse datasources", result[:alerts][2][:subject]
    assert_equal "Could not parse latencies", result[:alerts][3][:subject]
  end

end
