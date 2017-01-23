require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../openswan.rb', __FILE__)


class OpenswanTest < Test::Unit::TestCase

  def test_tunnel_up
    plugin=Openswan.new(nil,{},{})
    plugin.stubs(:`).with("service ipsec status").returns(File.read(File.dirname(__FILE__)+'/fixtures/up.txt'))

    res = plugin.run()
    assert res[:errors].empty?

    assert_equal [{ num_tunnels_up: 2}], res[:reports]
  end # test_success

  def test_tunnel_down
    plugin=Openswan.new(nil,{},{})
    plugin.stubs(:`).with("service ipsec status").returns(File.read(File.dirname(__FILE__)+'/fixtures/down.txt'))

    res = plugin.run()
    assert res[:errors].empty?

    assert_equal [{ num_tunnels_up: 0}], res[:reports]
  end # test_success

end
