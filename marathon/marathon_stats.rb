# Reports statistics for the Marathon apps using the statsd
# metrics format.
#
# Created by Lukas Lachowski (lukasz.lachowski@solarwinds.com)
#

class MarathonStats < Scout::Plugin
  needs "net/http", "uri", "json", "socket"

  OPTIONS=<<-EOS
      mesos_containers_url:
        name: Mesos Server containers REST API URL
        notes: Specify the URL of the server's containers REST API to check.
        default: "http://localhost/containers"
      statsd_address:
        name: StatsD daemon ip address
        notes: Specify the address for the StatsD daemon.
        default: "127.0.0.1"
      statsd_port:
        name: StatsD daemon port.
        notes: Specify the port for the StatsD daemon.
        default: 8125
      marathon_url:
        name: Marathon REST API URL
        notes: Specify the URL for the Marathon's REST API.
        default: "http://localhost/v2/apps/"
  EOS

  def build_report
    containers = get_containers()
    for container_data in containers do
      app_name = get_app_name(app_id)
      publish_statsd(container_data, app_name)
    end
  end

  def get_containers()
    begin
      mesos_uri = URI.parse(option(:mesos_url))
      return JSON.parse(make_request(mesos_uri))
    rescue => ex
      error = RuntimeError.new("Error while getting the list of Mesos containers. Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
  end

  def get_app_name(container_data)
    if !container_data.key?(:executor_id)
      raise "Missing the 'executor_id' attribute in data payload returned by Mesos."
    end
    app_id = container_data[:executor_id]
    app_id = parse_app_name(app_id)
    begin
      marathon_app_uri = URI.parse(option(:marathon_url)).join(app_id)
      app_data = JSON.parse(make_request(marathon_app_uri))
    rescue => ex
      error = RuntimeError.new("Error while getting application's details from Marathon. Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
    if !app_data.key?(:apps) || !app_data[:apps].is_a?(Array) || !app_data[:apps][0].key?(:id)
      raise "Missing 'app' or 'id' attribute in data payload returned by Marathon."
    end
    return app_data[:apps][0][:id]
  end

  def parse_app_name(container_id)
    app_name_match = container_id.match(/([^\.]+).*/)
    if app_name_match.nil?
      raise "Wrong 'container_id' format."
    end
    return "/%s" % app_name_match.captures[0]
  end

  def make_request(uri, username=nil, password=nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    req = Net::HTTP::Get.new(uri.path)
    if !username.nil? && !password.nil?
      req.basic_auth username, password
    end
    response = http.request(req)
    return response.body
  end

  def publish_statsd(container_data, app_name)
    if !container_data.key?(:statistics)
      raise "Missing the 'statistics' attribute in data payload returned by Marathon."
    end
    statistics = container_data[:statistics]
    statsd_values = json_to_statsd(statistics, app_name)
    statsd_values.each do |statsd|
      send_statsd(statsd)
    end
  end

  def json_to_statsd(json_data, prefix)
    results = []
    json_data.each do |k,v|
      results << to_statsd_gauge(prefix, k, v)
    end
    return results
  end

  def to_statsd_gauge(prefix, key, value)
    return "%s.%s:%s|g" % [prefix, key.to_s, value.to_s]
  end

  def send_statsd(statsd)
    begin
      scoutd_address = option(:statsd_address)
      scoutd_port = option(:statsd_port)
      @socket.send(statsd, 0, scoutd_address, scoutd_port)
    rescue => ex
      error = RuntimeError.new("Error while sending StatsD data to Scout. Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
  end

end
