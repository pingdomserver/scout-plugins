require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../etcd.rb', __FILE__)


class EtcdStatsTest < Test::Unit::TestCase
  def test_no_errors
    etcd_running = %x'ps aux |grep etcd'.include? "./etcd"
    assert(etcd_running, "Etcd is not currently running, please run it before running the test")
    plugin = EtcdStats.new(nil,{},{})
    res = plugin.run
    assert res[:errors].empty?
    has_name = false
    res[:reports].each do |k|
      if k.has_key?(:name) then
        has_name = true
      end
    end
    assert has_name.eql? true

  end
end
