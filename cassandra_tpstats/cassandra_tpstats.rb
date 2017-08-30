# Reports Cassandra ReadStage thread pools statistics
#
# Created by Oskar Kapusta on 2017-08-11.
# ==============================================================================

class CassandraTPStats < Scout::Plugin
  OPTIONS = <<-EOS
    host:
      default: localhost
      notes: Node hostname or ip address
    port: 
      default: 7199
      notes: Remote jmx agent port number
    password:
      notes: Remote jmx agent password
    password_file: 
      notes: Path to the jmx password file
    username:
      notes: Remote jmx username
  EOS
  
  def build_report
    gather_facts["ThreadPools"]["ReadStage"].each do |k, v|
      report(:"#{k}" => v)
    end
  end
  
  private
  
  def gather_facts
    @facts ||= JSON.parse(%x(nodetool #{options} tpstats -F json))
  end
  
  def options
    option_string = String.new
    @options.each do |k, v|
      option_string << " --#{k.gsub(/_/, '-')} #{v}" if v
    end
    
    option_string
  end
  
end