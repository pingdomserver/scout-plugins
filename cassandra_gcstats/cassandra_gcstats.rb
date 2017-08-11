# Reports Cassandra garbage collector statistics
#
# Created by Oskar Kapusta on 2017-08-11.
# ==============================================================================

class CassandraGCStats < Scout::Plugin
  class DataConsistencyError < StandardError; end;
  
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
    ensure_data_consistency!
    
    report(Hash[headers.zip(values)])
  end
  
  private
  
  attr_reader :headers, :values
  
  def gather_facts
    @facts ||= %x(nodetool #{options} gcstats)
  end
  
  def parsed_headers
    header_line = gather_facts.lines.first.lstrip.chomp
  
    @headers ||= header_line.split(/\)/).join(')  ').split(/\s{2,}/)
  end
  
  def parsed_values
    @values ||= gather_facts.lines.last.lstrip.split(/\s+/)
  end
  
  def ensure_data_consistency!
    unless parsed_headers.length == parsed_values.length
      raise DataConsistencyError, "Headers don't match values"
    end
  end
  
  def options
    option_string = String.new
    @options.each do |k, v|
      option_string << " --#{k.gsub(/_/, '-')} #{v}" if v
    end
    
    option_string
  end
end
