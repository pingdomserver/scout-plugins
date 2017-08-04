require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mpstat.rb', __FILE__)

class TestMPstat < Test::Unit::TestCase

  METRIC_KEYS = {:user=>"0.31", :nice=>"0.00", :sys=>"1.97", :iowait=>"0.00", :irq=>"0.00",
     :soft=>"0.10", :steal=>"0.00", :idle=>"97.61", :intrps=>nil}

  def test_should_work_with_dots
    @plugin = MPstat.new nil, {}, {}

    @plugin.stubs(:stat_output).returns(File.read(File.dirname(__FILE__)+'/fixtures/output_with_dot.txt'))

    result = @plugin.run
    # Errors should be empty
    assert result[:errors].empty?

    # Shuld have parsed results
    result[:reports][0].each do |key, value|
      assert METRIC_KEYS[key].eql? value
    end
  end

  def test_should_work_with_commas
    @plugin = MPstat.new nil, {}, {}

    @plugin.stubs(:stat_output).returns(File.read(File.dirname(__FILE__)+'/fixtures/output_with_comma.txt'))

    result = @plugin.run
    # Errors should be empty
    assert result[:errors].empty?

    # Shuld have parsed results
    result[:reports][0].each do |key, value|
      assert METRIC_KEYS[key].eql? value
    end
  end
end
