# Reports stats on a node in the elasticsearch cluster, including size of indices,
# number of docs, memory used, threads used, garbage collection times, etc
#
# Created by John Wood of Signal
class ElasticsearchClusterNodeStatus < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: elasticsearch host
      notes: The host elasticsearch is running on
    elasticsearch_port:
      default: 9200
      name: elasticsearch port
      notes: The port elasticsearch is running on
    username:
      deault: nil
      name: Username
      notes: Username used to log into elasticsearch host if authentication is enabled.
    password:
      deault: nil
      name: Password
      notes: Password used to log into elasticsearch host if authentication is enabled.
    node_name:
      name: Node name
      notes: Name of the cluster node you wish to monitor
  EOS

  needs 'net/http', 'json', 'cgi', 'open-uri'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil? || option(:node_name).nil?
      return error("Please provide the host, port, and node name", "The elasticsearch host, port, and node to monitor are required.\n\nelasticsearch Host: #{option(:elasticsearch_host)}\n\nelasticsearch Port: #{option(:elasticsearch_port)}\n\nNode Name: #{option(:node_name)}")
    end

    if option(:username).nil? != option(:password).nil?
      return error("Please provide both username and password", "Both the elasticsearch username and password to monitor the protected cluster are required.\n\nUsername: #{option(:username)}\n\nPassword: #{option(:password)}")
    end

    node_name = CGI.escape(option(:node_name))

    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}#{uri_path}/#{node_name}/stats?all=true"
    req = Net::HTTP::Get.new(base_url)

    if !option(:username).nil? && !option(:password).nil?
      req.basic_auth option(:username), option(:password)
    end

    uri = URI.parse(base_url)
    response = Net::HTTP.get_response(uri)
    resp = JSON.parse(response.body)
    if resp['nodes'].nil? or resp['nodes'].empty?
      return error("No node found with the specified name", "No node in the cluster could be found with the specified name.\n\nNode Name: #{option(:node_name)}")
    end

    response = resp['nodes'].values.first
    report(:size_of_indices => b_to_mb(response['indices']['size_in_bytes']) || 0)
    report(:num_docs => (response['indices']['docs']['count'] rescue 0))
    report(:open_file_descriptors => response['process']['open_file_descriptors'] || 0)
    report(:heap_used => b_to_mb(response['jvm']['mem']['heap_used_in_bytes'] || 0))
    report(:heap_committed => b_to_mb(response['jvm']['mem']['heap_committed_in_bytes'] || 0))
    report(:non_heap_used => b_to_mb(response['jvm']['mem']['non_heap_used_in_bytes'] || 0))
    report(:non_heap_committed => b_to_mb(response['jvm']['mem']['non_heap_committed_in_bytes'] || 0))
    report(:threads_count => response['jvm']['threads']['count'] || 0)

    gc_time(:gc_collection_time => response['jvm']['gc'])
    # Additional GC metrics provided by ElasticSearch can vary:
    gc_time(:gc_parnew_collection_time => response['jvm']['gc']['collectors']['ParNew']) if response['jvm']['gc']['collectors']['ParNew']
    gc_time(:gc_cms_collection_time => response['jvm']['gc']['collectors']['ConcurrentMarkSweep']) if response['jvm']['gc']['collectors']['ConcurrentMarkSweep']
    gc_time(:gc_copy_collection_time => response['jvm']['gc']['collectors']['Copy']) if response['jvm']['gc']['collectors']['Copy']
    gc_time(:gc_msc_coolection_time => response['jvm']['gc']['collectors']['MarkSweepCompact']) if response['jvm']['gc']['collectors']['MarkSweepCompact']

  rescue OpenURI::HTTPError
    error("Stats URL not found", "Please ensure the base url for elasticsearch cluster node stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid", "Please ensure the elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  rescue Errno::ECONNREFUSED
    error("Unable to connect", "Please ensure the host and port are correct. Current URL: \n\n#{base_url}")
  end

  def b_to_mb(bytes)
    bytes && bytes.to_f / 1024 / 1024
  end

  # Reports the time spent in collection / # of collections for this reporting period.
  def gc_time(data)
    key = data.keys.first.to_s
    collection_time = data.values.first['collection_time_in_millis'] || 0
    collection_count = data.values.first['collection_count'] || 1

    previous_collection_time = memory(key)
    previous_collection_count = memory(key.sub('time','count'))

    if previous_collection_time and previous_collection_count
      rate = (collection_time-previous_collection_time).to_f/(collection_count-previous_collection_count)
      if rate >=0 # assuming that restarting elasticsearch restarts counts, which means the rate could be < 0.
        report(data.keys.first => rate)
      elsif rate.nan? # no activity
        report(data.keys.first => 0)
      end
    end

    remember(key => collection_time || 0)
    remember(key.sub('time','count') => collection_count || 1)
  end

  # ES >= 1.0 has a different stats endpoint.
  def uri_path
    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/"
    req = Net::HTTP::Get.new(base_url)
    if !option(:username).nil? && !option(:password).nil?
      req.basic_auth option(:username), option(:password)
    end

    uri = URI.parse(base_url)
    response = Net::HTTP.get_response(uri)
    resp = JSON.parse(response.body)
    if resp['version'] and resp['version']['number'].to_f >= 1
      '/_nodes'
    else
      '/_cluster/nodes'
    end
  end
end
