# Reports statistics for the Marathon apps using the statsd
# metrics format.
#
# Created by Lukas Lachowski (lukasz.lachowski@solarwinds.com)
#

class MarathonStats < Scout::Plugin
  needs "net/http", "uri", "json", "socket", "logger"

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
      marathon_apps_url:
        name: Marathon REST API URL
        notes: Specify the URL for the Marathon's REST API.
        default: "http://localhost/v2/apps/"
      marathon_username:
        name: Marathon Username
        default:
      marathon_password:
        name: Marathos Password
        default:
      mesos_username:
        name: Mesos Useraname
        default:
      mesos_password:
        name: Mesos Password
        default:
  EOS

  def initialize(last_run, memory, options)
    super(last_run, memory, options)
    initialize_report()
  end

  def get_marathon_app_url
    return option(:marathon_apps_url)
  end

  def build_report
    begin
      containers = get_containers()
      apps = get_apps()
      for app_data in apps do
        raise "Missing 'id' attribute in apps data payload from Marathon." unless app_data.key?("id")
        app_id = app_data["id"]
        app_data = get_app_data(app_id)
        unless app_data.key?("tasks") && app_data["tasks"].is_a?(Array)
          raise "Invalid/missing 'tasks' attribute in data payload from Marathon. Data: %s" % app_data.to_s
        end
        for task in app_data["tasks"] do
          raise "Missing 'task.id' in data payload from Marathon." unless task.key?("id")
          task_id = task["id"]
          container = find_container(task_id, containers)
          if container.nil?
            next
          end
          task_name = "%s.%s" % [app_id, task_id]

          publish_statsd(container, task_name)
        end
      end
    rescue => ex
      log_debug(ex)
      raise ex
    end
  end

  def initialize_report()
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @socket = UDPSocket.new
  end

  def find_container(task_id, containers)
    return containers.find{ |x| x["executor_id"] == task_id}
  end

  def get_containers
    begin
      mesos_uri = URI.parse(option(:mesos_containers_url))
      log_debug("Downloading the list of Mesos containers - url: %s" % mesos_uri)
      return JSON.parse(make_request(mesos_uri, option(:mesos_username), option(:mesos_password)))
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
      apps = JSON.parse(make_request(marathon_apps_uri, option(:marathon_username),
                        option(:marathon_password)))
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
      app_data_json = make_request(marathon_app_uri, option(:marathon_username),
                                         option(:marathon_password))
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
    unless container_data.key?("statistics")
      raise "Missing the 'statistics' attribute in data payload returned by Marathon." 
    end
    statistics = container_data["statistics"]
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
    return "%s.%s:%s|g" % [prefix, key.to_s, value.to_s]
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
