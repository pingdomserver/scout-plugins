class ElasticsearchClusterNodeStatusPlugin < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: elasticsearch host
      notes: The host elasticsearch is running on
    elasticsearch_port:
      default: 9200
      name: elasticsearch port
      notes: The port elasticsearch is running on
    node_name:
      name: Node name
      notes: Name of the cluster node you wish to monitor
  EOS

  needs 'net/http', 'json', 'cgi'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil? || option(:node_name).nil?
      return error("Please provide the host, port, and node name", "The elasticsearch host, port, and node to monitor are required.\n\nelasticsearch Host: #{option(:elasticsearch_host)}\n\nelasticsearch Port: #{option(:elasticsearch_port)}\n\nNode Name: #{option(:node_name)}")
    end

    node_name = CGI.escape(option(:node_name))

    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/_cluster/nodes/#{node_name}/stats"
    resp = JSON.parse(Net::HTTP.get(URI.parse(base_url)))

    if resp['nodes'].empty?
      return error("No node found with the specified name", "No node in the cluster could be found with the specified name.\n\nNode Name: #{option(:node_name)}")
    end

    response = resp['nodes'].values.first

    report(:size_of_indices => b_to_mb(response['indices']['size_in_bytes']) || 0)
    report(:num_docs => response['indices']['docs']['num_docs'] || 0)
    report(:open_file_descriptors => response['process']['open_file_descriptors'] || 0)
    report(:heap_used => b_to_mb(response['jvm']['mem']['heap_used_in_bytes'] || 0))
    report(:heap_committed => b_to_mb(response['jvm']['mem']['heap_committed_in_bytes'] || 0))
    report(:non_heap_used => b_to_mb(response['jvm']['mem']['non_heap_used_in_bytes'] || 0))
    report(:non_heap_committed => b_to_mb(response['jvm']['mem']['non_heap_committed_in_bytes'] || 0))
    report(:threads_count => response['jvm']['threads']['count'] || 0)
    report(:gc_collection_time => response['jvm']['gc']['collection_time_in_millis'] || 0)
    report(:gc_parnew_collection_time => response['jvm']['gc']['collectors']['ParNew']['collection_time_in_millis'] || 0)
    report(:gc_cms_collection_time => response['jvm']['gc']['collectors']['ConcurrentMarkSweep']['collection_time_in_millis'] || 0)

  rescue OpenURI::HTTPError
    error("Stats URL not found", "Please ensure the base url for elasticsearch cluster node stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid", "Please ensure the elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  end

  def b_to_mb(bytes)
    bytes && bytes.to_f / 1024 / 1024
  end

end

