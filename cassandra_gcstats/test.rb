require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../cassandra_gcstats.rb', __FILE__)

class TestCassandraGCStats < Test::Unit::TestCase
  RESULT = {
    "Interval (ms)" => "36406",
    "Max GC Elapsed (ms)" => "0",
    "Total GC Elapsed (ms)" => "0",
    "Stdev GC Elapsed (ms)" => "NaN",
    "GC Reclaimed (MB)"=>"0",
    "Collections" => "0",
    "Direct Memory Bytes" => "-1"
  }.freeze

  
  
  def setup
    @options = YAML.load(
      File.read(File.expand_path('../fixtures/options.yml', __FILE__))
    )
    @plugin = CassandraGCStats.new nil, {}, @options
  end
  
  def test_should_parse_gathered_facts
    result = @plugin.run
    
    RESULT.keys.each do |key|
      assert result[:reports][0].has_key? key
    end
  end
  
  def test_parsed_headers_should_have_right_values
    @plugin.stubs(:gather_facts).returns(gcstats.split(/\n/))
    
    result = @plugin.run
    
    RESULT.each do |k, v|
      assert result[:reports][0][k] == v
    end
  end
  
  private
  
  def gcstats
    File.read(File.expand_path('../fixtures/gcstats', __FILE__))
  end
end
