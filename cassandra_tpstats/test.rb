require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../cassandra_tpstats.rb', __FILE__)

class TestCassandraTPStats < Test::Unit::TestCase
  def setup
    @options = YAML.load(
      File.read(File.expand_path('../fixtures/options.yml', __FILE__))
    )
    @plugin = CassandraTPStats.new nil, {}, @options
  end
  
  def test_result_has_all_values
    @plugin.stubs(:gather_facts).returns(tpstats)
    
    result = @plugin.run
      
    assert result[:reports].any?
  end
  
  private
  
  def tpstats
    JSON.parse(File.read(File.expand_path('../fixtures/tpstats', __FILE__)))
  end
end
