require 'sidekiq'
require 'sidekiq/testing'
require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../sidekiq_monitor.rb', __FILE__)

class SidekiqMonitorTest < Test::Unit::TestCase

  def test_default_options
    stats = stub(:enqueued => 1, :failed => 2, :processed => 3, :scheduled_size => 4, :retry_size => 5)
    conn = stub(:scard => 6)
    Sidekiq::Stats.stubs(:new).returns(stats)
    Sidekiq.stubs(:redis).yields(conn)
    Sidekiq.expects(:redis=).with({ :url => 'redis://localhost:6379/0', :namespace => nil })
    plugin = SidekiqMonitor.new(nil, {}, { :host => 'localhost', :port => 6379, :db => 0 })
    plugin.expects(:report).with({ :enqueued       => 1 }).once
    plugin.expects(:report).with({ :failed         => 2 }).once
    plugin.expects(:report).with({ :processed      => 3 }).once
    plugin.expects(:report).with({ :scheduled_size => 4 }).once
    plugin.expects(:report).with({ :retry_size     => 5 }).once
    plugin.expects(:report).with({ :running        => 6 }).once
    plugin.expects(:counter).with(:enqueued_per_minute,        1,  { :per => :minute }).once
    plugin.expects(:counter).with(:failed_per_minute,          2,  { :per => :minute }).once
    plugin.expects(:counter).with(:processed_per_minute,       3,  { :per => :minute }).once
    plugin.expects(:counter).with(:scheduled_size_per_minute,  4,  { :per => :minute }).once
    plugin.expects(:counter).with(:retry_size_per_minute,      5,  { :per => :minute }).once
    plugin.expects(:counter).with(:running_per_minute,         6,  { :per => :minute }).once
    plugin.run
  end

end
