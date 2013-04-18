require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../cloudkick_wrapper.rb', __FILE__)

class CloudkickWrapperTest < Test::Unit::TestCase
  def test_no_cloudkick_plugin_option
    plugin = CloudkickWrapper.new(nil, {}, {})
    plugin.expects(:error).with('no cloudkick_plugin option given')
    plugin.run
  end

  def test_executes_the_cloudkick_plugin_when_given_full_path
    plugin = CloudkickWrapper.new(nil, {}, {:cloudkick_plugin => '/path/to/plugin' })
    plugin.expects(:'`').with('/path/to/plugin').returns('status ok foo')
    plugin.run
  end

  def test_executes_the_cloudkick_plugin_when_only_given_name
    plugin = CloudkickWrapper.new(nil, {}, {:cloudkick_plugin => 'plugin' })
    plugin.expects(:'`').with('/usr/lib/cloudkick-agent/plugins/plugin').returns('status ok foo')
    plugin.run
  end

  # status line

  def test_with_ok_status
    plugin = CloudkickWrapper.new(nil, {}, {:cloudkick_plugin => 'test'})
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
    EOS
    plugin.expects(:report).with({:status => 0})
    plugin.run
  end

  def test_with_warn_status
    plugin = CloudkickWrapper.new(nil, {}, {:cloudkick_plugin => 'test'})
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status warn foobar
    EOS
    plugin.expects(:report).with({:status => 1})
    plugin.expects(:alert).never
    plugin.run
  end

  def test_with_err_status
    plugin = CloudkickWrapper.new(nil, {}, {:cloudkick_plugin => 'test'})
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status err foobar
    EOS
    plugin.expects(:report).with({:status => 1})
    plugin.expects(:alert).never
    plugin.run
  end
  
  def test_with_invalid_status_line
    plugin = CloudkickWrapper.new(nil, {}, {:cloudkick_plugin => 'test'})
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
foobar
    EOS
    assert_raises RuntimeError, 'invalid status line' do
      plugin.run
    end
  end

  # metrics

  def test_with_a_int_metric
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test int 1
    EOS
    plugin.expects(:report).with({:status => 0, :test => 1.0})
    plugin.run
  end

  def test_with_invalid_metric
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test foobar 5
    EOS
    assert_raises RuntimeError, 'invalid metric line' do
      plugin.run
    end
  end

  def test_with_complex_metric_name
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test_name_with_underscores int 1
    EOS
    plugin.expects(:report).with(:status => 0, :test_name_with_underscores => 1.0)
    plugin.run
  end

  def test_with_a_float_metric
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test float 1.5
    EOS
    plugin.expects(:report).with({:status => 0, :test => 1.5})
    plugin.run
  end

  def test_with_a_gauge_metric
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test gauge 500
    EOS
    plugin.expects(:report).with({:status => 0})
    plugin.expects(:counter).with(:test, 500, :per => :second)
    plugin.run
  end

  def test_ignores_string_metrics
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test string foo
    EOS
    plugin.expects(:report).with({:status => 0})
    plugin.run
  end

  def test_cloudkick_output_with_more_whitespace
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status         ok   foobar
metric  test1 int    1
metric     test2   int 5
    EOS
    plugin.expects(:report).with({
        :status => 0,
        :test1 => 1.0,
        :test2 => 5.0,
      })
    plugin.run
  end

  def test_multiple_metrics
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test1 int 1
metric test2 int 5
metric test3 float 15.75
metric test4 float 20
metric test5 string foo
metric test6 gauge 500
metric test7 gauge 1000
    EOS
    plugin.expects(:report).with({
        :status => 0,
        :test1 => 1.0,
        :test2 => 5.0,
        :test3 => 15.75,
        :test4 => 20.0,
      })
    plugin.expects(:counter).with(:test6, 500.0, :per => :second)
    plugin.expects(:counter).with(:test7, 1000.0, :per => :second)
    plugin.run
  end

  def test_scout_metric_limit
    plugin = CloudkickWrapper.new(nil, {}, :cloudkick_plugin => 'test')
    plugin.expects(:execute_cloudkick_plugin).returns(<<-EOS)
status ok foobar
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
metric test int 1
    EOS
    plugin.expects(:error).with('there are too many metrics, Scout only allows up to 20')
    plugin.run
  end
end
