require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mdstat.rb', __FILE__)

class MdStatTest < Test::Unit::TestCase
  def test_success      
    plugin=MdStat.new(nil,{},{})
    plugin.stubs(:`).with("cat /proc/mdstat").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_mdstat_raid5.txt'))

    res = plugin.run()
    assert res[:errors].empty?
    assert res[:memory][:mdstat_ok]
    assert_equal [{ :active_disks=>5, :spares=>0, :failed_disks=>0}], res[:reports]
  end # test_success  
  
  def test_error_with_raid_0
    plugin=MdStat.new(nil,{},{})
    plugin.stubs(:`).with("cat /proc/mdstat").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_mdstat_raid0.txt'))

    res = plugin.run()
    assert_equal 1, res[:errors].length
    assert_equal "Not applicable for RAID 0", res[:errors].first[:subject]
  end

  def test_multiple_arrays
    plugin = MdStat.new(nil, {}, { :monitor_multiple => "true" })
    plugin.stubs(:`).with("cat /proc/mdstat").returns(File.read(File.dirname(__FILE__) + '/fixtures/proc_mdstat_multiple.txt'))

    response = plugin.run()
    assert_equal [{ :active_disks => 4, :spares => 0, :failed_disks => 1 }], response[:reports]
  end

  def test_only_monitor_first_if_monitor_multiple_is_not_set
    plugin = MdStat.new(nil, {}, {})
    plugin.stubs(:`).with("cat /proc/mdstat").returns(File.read(File.dirname(__FILE__) + '/fixtures/proc_mdstat_multiple.txt'))

    response = plugin.run()
    assert_equal [{ :active_disks => 2, :spares => 0, :failed_disks => 0 }], response[:reports]
  end
end
