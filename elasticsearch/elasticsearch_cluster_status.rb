class ElasticsearchClusterStatusPlugin < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: elasticsearch host
      notes: The host elasticsearch is running on
    elasticsearch_port:
      default: 9200
      name: elasticsearch port
      notes: The port elasticsearch is running on
  EOS

  needs 'net/http', 'json'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil?
      return error("Please provide the host and port", "The elasticsearch host and port to monitor are required.\n\nelasticsearch Host: #{option(:elasticsearch_host)}\n\nelasticsearch Port: #{option(:elasticsearch_port)}")
    end

    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/_cluster/health"
    response = JSON.parse(Net::HTTP.get(URI.parse(base_url)))

    report(:status => response['status'])
    report(:number_of_nodes => response['number_of_nodes'])
    report(:number_of_data_nodes => response['number_of_data_nodes'])
    report(:active_primary_shards => response['active_primary_shards'])
    report(:active_shards => response['active_shards'])
    report(:relocating_shards => response['relocating_shards'])
    report(:initializing_shards => response['initializing_shards'])
    report(:unassigned_shards => response['unassigned_shards'])

  rescue OpenURI::HTTPError
    error("Stats URL not found", "Please ensure the base url for elasticsearch cluster stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid", "Please ensure the elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  end

end

