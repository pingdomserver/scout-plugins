class DockerMonitor < Scout::Plugin
  needs 'excon'

  OPTIONS=<<-EOS
    containers:
      name: Containers
      notes: comma-separated container names or ids (leave blank for all containers)
  EOS

  def build_report
    containers = containers_from_options || running_container_ids
    @stats = {:number_of_containers => number_of_running_containers, :cpu_percent => 0.0, :memory_usage => 0.0, :memory_limit => 0.0, :network_in => 0.0, :network_out => 0.0}
    containers.each do |container_id|
      add_container_stats(container_id)
    end
    report(@stats)
  end

  private

  def containers_from_options
    if @containers_from_options.nil?
      containers ||= option(:containers).to_s.split(",").map(&:strip).select { |container| !container.empty? }
      @containers_from_options = containers.empty? ? false : containers
    end
    @containers_from_options
  end

  def streamer(container_id)
    lambda do |chunk, remaining_bytes, total_bytes|
      parse_stats(container_id, chunk)
      # the api enpoint streams, raising breaks out of the streaming loop after the first datapoint is collected
      # TODO break this loop without raising an exception
      raise 'stats gathered'
    end
  end

  def add_container_stats(container_id)
    connection.request(:method => :get, :path => "/containers/#{container_id}/stats", :read_timeout => 10, :response_block => streamer(container_id))
  rescue Excon::Errors::Timeout # will timeout if the container does not exist
    # noop - simply ignore this container
  rescue Excon::Errors::SocketError => e # using exceptions for control flow. what a terrible idea.
    unless e.message.include?('stats gathered')
      error("Invalid Stats API endpoint", "There was an error reading from the stats API. Are you running Docker version 1.5 or higher, and is /var/run/docker.sock readable by the user running scout?\n\nException:#{e.message}\n\n#{e.backtrace}")
    end
  end

  def connection
    Excon.new('unix:///', :socket => socket_path, :debug => true)
  end

  def running_container_ids
    @running_container_ids ||= running_containers.map {|container| container["Id"]}
  end

  def running_container_names
    @running_container_names ||= running_containers.flat_map { |c| c["Names"] }.map { |name| name.gsub(/\A\//, '') } # remove beginning slash
  end

  def running_containers
    unless(@running_containers) # memoize
      response = connection.request(:method => :get, :path => "/containers/json")
      @running_containers = JSON.parse(response.body)
    end
    @running_containers
  end

  def number_of_running_containers
    if(containers_from_options)
      containers_from_options.select do |container|
        match_by_id = running_container_ids.select { |id| /\A#{container}/ =~ id }.count > 0
        match_by_name = running_container_names.include?(container)
        match_by_id || match_by_name
      end.count
    else
      running_container_ids.count
    end
  end

  def parse_stats(container_id, stats_string)
    unless(stats_string.include?('no such container'))
      stats = JSON.parse(stats_string)
      @stats[:cpu_percent] += calculate_cpu_percent(container_id, stats["cpu_stats"]["cpu_usage"]["total_usage"], stats["cpu_stats"]["system_cpu_usage"], stats["cpu_stats"]["cpu_usage"]["percpu_usage"].count)
      @stats[:memory_usage] += stats["memory_stats"]["usage"].to_f / 1024.0 / 1024.0 if stats["memory_stats"]
      @stats[:memory_limit] += stats["memory_stats"]["limit"].to_f / 1024.0 / 1024.0 if stats["memory_stats"]
      @stats[:network_in] += stats["network"]["rx_bytes"].to_f / 1024.0 if stats["network"]
      @stats[:network_out] += stats["network"]["tx_bytes"].to_f / 1024.0 if stats["network"]
    end
  end

  def calculate_cpu_percent(container_id, total_container_cpu, total_system_cpu, num_processors)
    # The CPU values returned by the docker api are cumulative for the life of the process, which is not what we want.
    now = Time.now
    last_cpu_stats = memory(container_id)
    if @last_run && last_cpu_stats
      container_cpu_delta = total_container_cpu - last_cpu_stats[:container_cpu]
      system_cpu_delta = total_system_cpu - last_cpu_stats[:system_cpu]
      cpu_percent = cpu_percent(container_cpu_delta, system_cpu_delta, num_processors)
    end
    remember(container_id => {:container_cpu => total_container_cpu, :system_cpu => total_system_cpu})
    return cpu_percent || 0
  end

  def cpu_percent(container_cpu_delta, system_cpu_delta, num_processors)
    # based on how the "docker stats" command calculates the cpu percent
    # https://github.com/docker/docker/blob/eb79acd7a0db494d9c6d1b1e970bdabf7c44ae4e/api/client/commands.go#L2758
    if(container_cpu_delta > 0.0 && system_cpu_delta > 0.0)
      container_cpu_delta.to_f / system_cpu_delta.to_f * num_processors.to_f * 100.0
    else
      0.0
    end
  end

  def socket_path
    unless(@socket_path)
      if(File.exists?('/host/var/run/docker.sock'))
        @socket_path = '/host/var/run/docker.sock'
      else
        @socket_path = '/var/run/docker.sock'
      end
    end
    @socket_path
  end
end
