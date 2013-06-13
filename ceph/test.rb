require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../ceph.rb', __FILE__)

class CephTest < Test::Unit::TestCase
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    
    def test_success_run
      data = IO.binread(File.dirname(__FILE__)+'/fixtures/ceph_ok')
      plugin = CephPlugin.new(nil, {}, {})
      ceph_status = CephPlugin::CephStatus.new(data)
      plugin.stubs(:new_ceph_status).returns(ceph_status)
      plugin.expects(:report).with(ceph_status.to_h)
      res = plugin.run
    end
    
    def test_success_status
      data = IO.binread(File.dirname(__FILE__)+'/fixtures/ceph_ok')
      plugin = CephPlugin.new(nil, {}, {})
      ceph_status = CephPlugin::CephStatus.new(data)
      plugin.stubs(:new_ceph_status).returns(ceph_status)
      res = plugin.run
      assert_equal CephPlugin::CephStatus::HEALTH_OK, res[:reports].first[:health]
      assert_equal 411.0, res[:reports].first[:data_size]
      assert_equal 634.0, res[:reports].first[:used]
      assert_equal 1314.0, res[:reports].first[:available]
      assert_equal 2024.0, res[:reports].first[:cluster_total_size]
      assert_equal 2, res[:reports].first[:num_osds]
      assert_equal 2, res[:reports].first[:osds_up]
      assert_equal 2, res[:reports].first[:osds_in]
    end
    
    def test_error_run
      data = IO.binread(File.dirname(__FILE__)+'/fixtures/ceph_unhealthy')
      plugin = CephPlugin.new(nil, {}, {})
      ceph_status = CephPlugin::CephStatus.new(data)
      plugin.stubs(:new_ceph_status).returns(ceph_status)
      plugin.expects(:report).with(ceph_status.to_h)
      res = plugin.run
    end
    
    def test_error_status
      data = IO.binread(File.dirname(__FILE__)+'/fixtures/ceph_unhealthy')
      plugin = CephPlugin.new(nil, {}, {})
      ceph_status = CephPlugin::CephStatus.new(data)
      plugin.stubs(:new_ceph_status).returns(ceph_status)
      res = plugin.run
      assert_equal CephPlugin::CephStatus::UNHEALTHY, res[:reports].first[:health]
      assert_equal "2304 pgs degraded; 2304 pgs stuck unclean; recovery 306763/613526 degraded (50.000%); 1/2 in osds are down", ceph_status.unhealthy_reason
      assert_equal 411.0, res[:reports].first[:data_size]
      assert_equal 760.0, res[:reports].first[:used]
      assert_equal 1191.0, res[:reports].first[:available]
      assert_equal 2024.0, res[:reports].first[:cluster_total_size]
      assert_equal 2, res[:reports].first[:num_osds]
      assert_equal 1, res[:reports].first[:osds_up]
      assert_equal 2, res[:reports].first[:osds_in]
    end
    
  
end