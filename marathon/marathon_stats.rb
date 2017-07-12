# Reports statistics for the Marathon apps using the statsd
# metrics format.
#
# Created by Lukas Lachowski (lukasz.lachowski@solarwinds.com)
#

class MarathonStats < Scout::Plugin
  needs "net/http", "uri", "json"

  OPTIONS=<<-EOS
      server_url:
        name: Server Status URL
        notes: Specify URL of the server-status page to check. Scout requires the machine-readable format of the status page (just add '?auto' to the server-status page URL).
        default: "http://localhost/server-status"
  EOS

  def build_report
    mesos_url = option("server_url")

    containers = JSON.parse(make_request(mesos_url))
    for container_data in containers do
      app_id = container_data["executor_id"]
      app_name = get_app_name(app_id)
      publish_statsd(container_data, app_name)
    end
  end

  def get_app_name(app_id)
    marathon_app_url = "marathon url/" + app_id

    app_data = JSON.parse(make_request(marathon_app_url))
    return app_data["id"]
  end

  def make_request(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    req = Net::HTTP::Get.new(uri.path)
    # req.basic_auth(option(:username), option(:password))
    response = http.request(req)
    return response.body
  end

  def publish_statsd(container_data, app_name)
    statistics = container_data["statistics"]
    statsd_values = json_to_statsd(statistics, app_name)
    statsd_values.each do |statsd|
      send_statsd(statsd)
    end
  end

  # STATSD = Statsd.new 'localhost', 8125

  def json_to_statsd(json_data, prefix)
    results = []
    json_data.each do |k,v|
      results << to_statsd_gauge(prefix, k, v)
    end
    return results
  end

  def to_statsd_gauge(prefix, key, value)
    return prefix + "." + key + ":" + value + "|g"
  end

  def send_statsd(statsd)
  end

end
