require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/fork_rate"

class ForkRateTest < Test::Unit::TestCase

  def test_success
    plugin=ForkRate.new({},{},{})
    plugin.stubs(:`).with("which vmstat").returns('/usr/bin/vmstat').once
    plugin.stubs(:`).with("/usr/bin/vmstat -f|awk '{print $1}'").returns(217083885)

    result = plugin.run

    assert result[:errors].empty?
    assert_equal 217083885, result[:memory]['_counter_forks'][:value]
  end
end

