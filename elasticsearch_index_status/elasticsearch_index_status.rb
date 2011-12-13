# Reports stats on an elasticsearch index, including index size, number of documents, etc.
#
# Created by John Wood of Signal
class ElasticsearchIndexStatus < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: elasticsearch host
      notes: The host elasticsearch is running on
    elasticsearch_port:
      default: 9200
      name: elasticsearch port
      notes: The port elasticsearch is running on
    index_name:
      name: Index name
      notes: Name of the index you wish to monitor
  EOS

  needs 'net/http', 'json', 'open-uri'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil? || option(:index_name).nil?
      return error("Please provide the host, port, and index name", "The elasticsearch host, port, and index to monitor are required.\n\nelasticsearch Host: #{option(:elasticsearch_host)}\n\nelasticsearch Port: #{option(:elasticsearch_port)}\n\nIndex Name: #{option(:index_name)}")
    end

    index_name = option(:index_name)

    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/#{index_name}/_stats"
    response = JSON.parse(Net::HTTP.get(URI.parse(base_url)))

    if response['error'] && response['error'] =~ /IndexMissingException/
      return error("No index found with the specified name", "No index could be found with the specified name.\n\nIndex Name: #{option(:index_name)}")
    end

    report(:primary_size => b_to_mb(response['_all']['indices'][index_name]['primaries']['store']['size_in_bytes']) || 0)
    report(:size => b_to_mb(response['_all']['indices'][index_name]['total']['store']['size_in_bytes']) || 0)
    report(:num_docs => response['_all']['indices'][index_name]['primaries']['docs']['count'] || 0)

  rescue OpenURI::HTTPError
    error("Stats URL not found", "Please ensure the base url for elasticsearch index stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid", "Please ensure the elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  end

  def b_to_mb(bytes)
    bytes && bytes.to_f / 1024 / 1024
  end

end

