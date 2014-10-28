# Reports stats on an elasticsearch cluster, including health (green, yellow, red),
# number of nodes, number of shards, etc
#
# Created by John Wood of Signal
class ElasticsearchClusterStatus < Scout::Plugin

  OPTIONS = <<-EOS
    elasticsearch_host:
      default: http://127.0.0.1
      name: Host
      notes: The host elasticsearch is running on
    elasticsearch_port:
      default: 9200
      name: Port
      notes: The port elasticsearch is running on
    username:
      deault: nil
      name: Username
      notes: Username used to log into elasticsearch host if authentication is enabled.
    password:
      deault: nil
      name: Password
      notes: Password used to log into elasticsearch host if authentication is enabled.
    alert_on_change:
      default: true
      name: alert on any change
      notes: Generate an internal alert any time the cluster status changes
  EOS

  needs 'net/http', 'json', 'open-uri'

  def build_report
    if option(:elasticsearch_host).nil? || option(:elasticsearch_port).nil?
      return error("Please provide the host and port", "The elasticsearch host and port to monitor are required.\n\nHost: #{option(:elasticsearch_host)}\n\nPort: #{option(:elasticsearch_port)}")
    end

    if option(:username).nil? != option(:password).nil?
      return error("Please provide both username and password", "Both the elasticsearch username and password to monitor the protected cluster are required.\n\nUsername: #{option(:username)}\n\nPassword: #{option(:password)}")
    end

    base_url = "#{option(:elasticsearch_host)}:#{option(:elasticsearch_port)}/_cluster/health"
    req = Net::HTTP::Get.new(base_url)

    if !option(:username).nil? && !option(:password).nil?
      req.basic_auth option(:username), option(:password)
    end

    uri = URI.parse(base_url)
    resp = Net::HTTP.get_response(uri)
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

  rescue OpenURI::HTTPError
    error("Stats URL not found", "Please ensure the base url for elasticsearch cluster stats is correct. Current URL: \n\n#{base_url}")
  rescue SocketError
    error("Hostname is invalid", "Please ensure the elasticsearch Host is correct - the host could not be found. Current URL: \n\n#{base_url}")
  rescue Errno::ECONNREFUSED
    error("Unable to connect", "Please ensure the host and port are correct. Current URL: \n\n#{base_url}")
  end

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
