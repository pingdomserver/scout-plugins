#################################################
# Cassandra
#
#   Report on Cassandra cluster health
#
# Created by Matt Chesler 2016-04-20
#################################################

class Cassandra < Scout::Plugin
  needs 'csv'

  class BinaryNotFoundError < RuntimeError; end
  class ConnectionError < RuntimeError; end

  SIZE_SUFFIXES = ['KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']

  OPTIONS=<<-EOS
    nodetool_path:
      name: Nodetool Path
      default: /usr/bin/nodetool
      notes: Path to Cassandra's nodetool
  EOS

  def build_report
    data_centers = process_data_centers(parse_output(execute_command))

    report(
      :total_datacenters => data_centers.size,
      :total_nodes       => data_centers.collect { |dc| dc[:nodes].size }.reduce(:+),
      :avg_node_load     => avg_node_load(data_centers),
      :up_nodes          => nodes_by_status(data_centers, 'UN'),
      :down_nodes        => nodes_by_status(data_centers, 'DN')
    )
  rescue BinaryNotFoundError
    alert("Cannot find Cassandra nodetool binary")
  rescue ConnectionError => e
    alert("Unable to connect to Cassandra", e.message)
  end

  protected
  def nodes_by_status(data_centers, status)
    data_centers.collect{|dc| dc[:nodes].select{|n| n[:status] == status}.size }.reduce :+
  end

  def avg_node_load(data_centers)
    loads = data_centers.collect{|dc| dc[:nodes].collect{|n| n[:load] } }.flatten
    (loads.collect{|l| load_to_number(l) }.reduce(:+) / loads.size).to_i
  end

  def load_to_number(load)
    value, suffix = load.match(/(\d+\.\d+) (['A-Z']{2})$/)[1..2]
    value = value.to_f
    magnitude = SIZE_SUFFIXES.index(suffix) + 1
    magnitude.times{ value = value * 1024}
    value
  end

  def nodetool_bin
    raise BinaryNotFoundError unless File.exist?(option(:nodetool_path))
    @nodetool ||= option(:nodetool_path)
  end

  def execute_command
    output = `#{nodetool_bin} status 2>&1`
    exit_code = $?.to_i

    { :exit_code => exit_code, :output => output }
  end

  def parse_output(results)
    if results[:exit_code] != 0
      raise ConnectionError, results[:output].chomp
    else
      data_centers = []
      current_data_center = nil
      results[:output].each_line do |line|
        next if line.strip.empty?
        case line
        when /Datacenter\:/
          current_data_center = {}
          current_data_center[:name] = line.match(/\: (.+)/)[1]
          data_centers << current_data_center
        when /\-\-/
          current_data_center[:csv] = line
        end
        next unless current_data_center && current_data_center[:csv]
        current_data_center[:csv] << line
      end
      return data_centers
    end
  end

  def process_data_centers(data_centers)
    data_centers.each do |data_center|
      data_center[:nodes] = []
      csv_string = data_center.delete(:csv)
      next unless csv_string
      keys = []
      csv_string.lines.each do |line|
        case line
        when /^--/
          keys = line.split(/\s{2}+/).collect do |key|
            case key
            when /--/
              :status
            else
              key.strip.gsub(' ', '_').downcase.to_sym
            end
          end
        else
          values = line.split(/\s{2}+/)
          node_hash = {}
          keys.each_with_index do |key, i|
            node_hash[key] = values[i].strip
          end
          data_center[:nodes] << node_hash
        end
      end
    end
    data_centers
  end
end
