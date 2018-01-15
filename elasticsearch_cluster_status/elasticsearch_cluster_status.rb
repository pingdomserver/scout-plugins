# Reports stats on an elasticsearch cluster, including health (green, yellow, red),
# number of nodes, number of shards, etc
#
# Created by John Wood of Signal
class ElasticsearchClusterStatus < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: Host URL
      notes: "The URL to the host elasticsearch is running on. Include the protocal (http:// or https://) in the URL."
    elasticsearch_port:
      default: 9200
      name: Port
      notes: The port elasticsearch is running on
    username:
      default: nil
      name: Username
      notes: Username used to log into elasticsearch host if authentication is enabled.
    password:
      default: nil
      name: Password
      notes: Password used to log into elasticsearch host if authentication is enabled.
    alert_on_change:
      default: true
      name: alert on any change
      notes: Generate an internal alert any time the cluster status changes
  EOS

  needs 'net/http', 'net/https', 'json', 'open-uri'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil?
      return error("Please provide the host and port", "The elasticsearch host and port to monitor are required.\n\nHost: #{option(:elasticsearch_host)}\n\nPort: #{option(:elasticsearch_port)}")
    end

    if option(:username).nil? != option(:password).nil?
      return error("Please provide both username and password", "Both the elasticsearch username and password to monitor the protected cluster are required.\n\nUsername: #{option(:username)}\n\nPassword: #{option(:password)}")
    end

    return if health_metrics.nil? # don't fetch index stats as these will likely error as well.
    index_metrics
  end

  def health_metrics
    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/_cluster/health"
    resp = get_response(base_url)
    if errors.any?
      remember_states
      return
    end
    response = JSON.parse(resp.body)

    report(:status => status(response['status']))
    report(:number_of_nodes => response['number_of_nodes'])
    report(:number_of_data_nodes => response['number_of_data_nodes'])
    report(:active_primary_shards => response['active_primary_shards'])
    report(:active_shards => response['active_shards'])
    report(:relocating_shards => response['relocating_shards'])
    report(:initializing_shards => response['initializing_shards'])
    report(:unassigned_shards => response['unassigned_shards'])

    # Send an alert every time cluster status changes, if enabled
    if truthy?(option(:alert_on_change)) && memory(:cluster_status) && memory(:cluster_status) != response['status']
      alert("elasticsearch cluster status changed to '#{response['status']}'","elasticsearch cluster health status changed from '#{memory(:cluster_status)}' to '#{response['status']}'")
    end
    remember :cluster_status => response['status']
  end

  def index_metrics
    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/_nodes/_local/stats/indices"
    resp = get_response(base_url)
    if errors.any?
      remember_states
      return
    end
    response = JSON.parse(resp.body)

    search_stats = response['nodes'].values.first['indices']['search']
    # sample
    # {"open_contexts"=>0, "query_total"=>319796, "query_time_in_millis"=>22074525, "query_current"=>0, "fetch_total"=>12014, "fetch_time_in_millis"=>698430, "fetch_current"=>0} 
    queries_before = memory("_counter_query_rate")
    query_total = search_stats['query_total']
    query_time = search_stats['query_time_in_millis']
    counter(:query_rate, query_total, :per => :second)
    last_query_time = memory("last_query_time")
    if queries_before and !last_query_time.nil?
      avg_query_time = (query_time - last_query_time)/(query_total-queries_before[:value]).to_f
      report(:query_time=>avg_query_time) if avg_query_time >= 0 # handle a reset
    end
    remember(:last_query_time,query_time)
  end

  # On error, want to keep previous memory values. 
  def remember_states
    remember(:cluster_status, memory(:cluster_status))
    remember(:last_query_time, memory(:last_query_time))
  end

  # All of the elasticsearch methods use this same logic. If this needs an update, an update may be required in others as well.
  def get_response(base_url)
    uri = URI.parse(base_url)

    http = Net::HTTP.new(uri.host,uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.start { |h|
      req = Net::HTTP::Get.new(uri.path.to_s+"?"+uri.query.to_s)
      if !option(:username).nil? && !option(:password).nil?
        req.basic_auth option(:username), option(:password)
      end
      response = h.request(req)
    }
  rescue OpenURI::HTTPError
    error("Cluster Health URL not found", "Please ensure the base url for elasticsearch cluster stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError,URI::InvalidURIError
    error("Hostname is invalid", "Please ensure the Elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  rescue Errno::ECONNREFUSED
    error("Unable to connect", "Please ensure the host and port are correct. Current URL: \n\n#{base_url}")
  end

  # Returns a Hash of the JSON response. If an error

  def truthy?(val)
    !val.nil? && val.to_s.downcase.strip == "true"
  end

  # Generates a status string like "2 (green)" so triggers can be run off the status.
  def status(color)
    code = case color
    when 'green'
      2
    when 'yellow'
      1
    when 'red'
      0
    end
    "#{code} (#{color})"
  end

end
