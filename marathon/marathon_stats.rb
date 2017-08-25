# Reports statistics for the Marathon apps using the statsd
# metrics format.
#
# Created by Lukas Lachowski & Kamil Sluszniak (lukasz.lachowski@solarwinds.com)
#
# TODO: this version follows the algorithm described in README.md, with an exception that it sends
# all metrics of a slave (slave's /metrics/snapshot rest endpoint) as mapped exclusively to a task
# (1-to-1 slave/task mapping).
#

class MarathonStats < Scout::Plugin
  needs "net/http", "uri", "json", "socket", "logger", "pry"

  OPTIONS=<<-EOS
      marathon_apps_url:
        name: Marathon REST API URL
        notes: Specify the URL for the Marathon's REST API.
        default: "http://192.168.65.90:8080/v2/apps"
      mesos_port:
        name: Mesos REST endpoint port
        default: 5051
      statsd_address:
        name: StatsD daemon ip address
        notes: Specify the address for the StatsD daemon.
        default: "127.0.0.1"
      statsd_port:
        name: StatsD daemon port.
        notes: Specify the port for the StatsD daemon.
        default: 8125
  EOS

  def initialize(last_run, memory, options)
    super(last_run, memory, options)
    initialize_report()
  end

  def build_report
    begin
      apps = get_apps()
      for app_data in apps do
        raise "Missing 'id' attribute in apps data payload from Marathon." unless app_data.key?("id")
        app_id = app_data["id"]
        app_data = get_app_data(app_id)
        unless app_data.key?("tasks") && app_data["tasks"].is_a?(Array)
          raise "Invalid/missing 'tasks' attribute in data payload from Marathon. Data: %s" %
                app_data.to_s
        end
        for task in app_data["tasks"] do
          task_id, metrics = get_task_metrics(task)
           

          task_name = "%s.%s" % [app_id, task_id]
          stats = {}
          
          mem = memory(:"#{task_name}_stats")
          if mem
            
            cpu_usage = (
                    (metrics["cpus_system_time_secs"] - mem["cpus_system_time_secs"]) +
                    (metrics["cpus_user_time_secs"] - mem["cpus_user_time_secs"])) / 
                    (metrics["timestamp"] - mem["timestamp"])
                    
            stats[:"#{task_name}_cpu_usage_percent"] = (cpu_usage * 100 )
                    
            stats[:"#{task_name}_memory_usage_bytes"] = metrics["mem_rss_bytes"].to_f
            stats[:"#{task_name}_memory_usage_percent"] = (metrics["mem_rss_bytes"].to_f /  (metrics["slave/mem_total"].to_f * 1048576)) * 100.0   
            publish_statsd(stats, task_name)     
          end
          remember(:"#{task_name}_stats" => metrics)
        end
      end
    rescue => ex
      log_debug(ex)
      raise ex
    end
  end

  def get_task_metrics(task)
    raise "Missing 'task.id' attribute in data payload from Marathon." unless task.key?("id")
    task_id = task["id"]
    raise "Missing 'host' attribute in data payload from Marathon." unless task.key?("host")
    host = task["host"]
    rest_endpoint = get_containers_uri(host)
    containers = get_containers(rest_endpoint)
    container = find_container(task_id, containers)
    if container.nil?
      raise "Unknown container: %s." % task_id
    end
    unless container.key?("statistics")
      raise "Missing the 'statistics' attribute in data payload returned by Marathon."
    end
    slave_metrics = get_slave_metrics(host)
    return task_id, container["statistics"].merge(slave_metrics)
  end

  def get_slave_metrics(host)
    begin
      slave_uri = URI.parse(get_slave_uri(host) + "/metrics/snapshot")
      log_debug("Downloading mesos slave's metrics - url: %s" % slave_uri)
      return JSON.parse(make_request(slave_uri))
    rescue => ex
      error = RuntimeError.new("Error while getting mesos slave's metrics."\
                               "Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
  end

  def get_slave_uri(host)
    return "http://%s:%s" % [host, get_mesos_port()]
  end

  def get_containers_uri(host)
    return "%s%s" % [get_slave_uri(host), "/containers"]
  end

  def get_mesos_port
    return option(:mesos_port)
  end

  def get_marathon_app_url
    return option(:marathon_apps_url)
  end

  def initialize_report()
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @socket = UDPSocket.new
  end

  def find_container(task_id, containers)
    return containers.find{ |x| x["executor_id"] == task_id}
  end

  def get_containers(uri)
    begin
      mesos_uri = URI.parse(uri)
      log_debug("Downloading the list of Mesos containers - url: %s" % mesos_uri)
      return JSON.parse(make_request(mesos_uri))
    rescue => ex
      error = RuntimeError.new("Error while getting the list of Mesos containers."\
                               "Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
  end

  def get_apps
    begin
      marathon_apps_uri = URI.parse(get_marathon_app_url)
      log_debug("Downloading the list of Marathon applications - url: %s" % marathon_apps_uri)
      apps = JSON.parse(make_request(marathon_apps_uri))
    rescue => ex
      error = RuntimeError.new("Error while downloading apps list from Marathon."\
                               "Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
    raise "Missing 'apps' attribute in data payload returned by Marathon." unless apps.key?("apps")
    return apps["apps"]
  end

  def get_app_data(app_id)
    begin
      marathon_app_uri = URI.parse("%s/%s" % [get_marathon_app_url, app_id.to_s])
      log_debug("Downloading details of some app with id=%s using url: %s" % [app_id.to_s, marathon_app_uri])
      app_data_json = make_request(marathon_app_uri)
    rescue => ex
      error = RuntimeError.new("Error while getting application's details from Marathon."\
                               " App_id: %s. URI: %s. Original message: %s" %
                               [app_id, marathon_app_uri, ex.message])
      error.set_backtrace(ex.backtrace)
      raise error
    end
    app_data  = JSON.parse(app_data_json)
    raise "Missing 'app' attribute in data payload returned by Marathon." unless app_data.key?("app")
    return app_data["app"]

  end

  def make_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    req = Net::HTTP::Get.new(uri.path)
    response = http.request(req)
    return response.body
  end

  def publish_statsd(statistics, app_name)
    statsd_values = container_data_to_statsd(statistics, app_name)
    statsd_values.each do |statsd|
      send_statsd(statsd, option(:statsd_address), option(:statsd_port))
    end
  end

  def container_data_to_statsd(container_data, prefix=nil)
    return container_data.to_a.map do |v|
      to_statsd_gauge(prefix, v[0], v[1])
    end
  end

  def to_statsd_gauge(prefix, key, value)
    return "%s.%s:%s|c" % [prefix, key.to_s, value.to_s]
  end

  def send_statsd(statsd, scoutd_address, scoutd_port)
    begin
      log_debug("Sending statsd data to %s:%s. Data: %s" % [scoutd_address, scoutd_port, statsd])
      @socket.send(statsd, 0, scoutd_address, scoutd_port)
    rescue => ex
      error = RuntimeError.new("Error while sending StatsD data to Scout."\
                               " Original message: %s" % ex.message)
      error.set_backtrace(ex.backtrace)
      raise error
    end
  end

  def log_debug(message)
    @logger.debug(message)
  end

end
