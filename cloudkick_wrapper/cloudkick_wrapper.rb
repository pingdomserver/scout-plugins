class CloudkickWrapper < Scout::Plugin
  OPTIONS=<<-EOS
    cloudkick_plugin:
      name: Coudkick plugin
      notes: The Cloudkick plugin to run, if no full path is given, /usr/lib/cloudkick-agent/plugins is checked.
  EOS

  CLOUDKICK_PLUGIN_DIRECTORY = '/usr/lib/cloudkick-agent/plugins'
  
  def build_report
    check_options
    if option(:cloudkick_plugin)
      plugin_output = execute_cloudkick_plugin
      lines = plugin_output.lines.to_a
      status = parse_status_line lines.shift
      metrics, counters = parse_metrics lines
      report({:status => status}.merge(metrics))
      counters.each do |c|
        counter(c[:name], c[:value], :per => :second)
      end
    end
  end

  def parse_status_line line
    if line && line.chomp =~ /^status +(ok|warn|err) +.+$/
      if $1 == 'ok'
        0
      else
        1
      end
    else
      raise 'invalid status line'
    end
  end

  def parse_metrics lines
    # there is a limit of 20 metrics per plugin instance and status
    # uses up one of them
    if lines.size <= 19
      all = lines.map do |line|
        parse_metric line
      end

      counters, metrics = all.partition {|m| m[:counter] }

      metrics = if metrics.empty?
                  {}
                else
                  metrics.inject(&:merge)
                end

      [metrics, counters]
    else
      error('there are too many metrics, Scout only allows up to 20')
      [{},[]]
    end
  end

  def parse_metric line
    if line && line.chomp =~ /^metric +([^ ]+) +(int|float|gauge|string) +(.+)$/
      name, type, value = $1.to_sym, $2, $3
      case type
      when 'int','float'
        { name => value.to_f }
      when 'gauge'
        {
          :name => name,
          :value => value.to_f,
          :counter => true,
        }
      when 'string'
        {}
      end
    else
      raise 'invalid metric line'
    end
  end

  def execute_cloudkick_plugin
    plugin_path = if option(:cloudkick_plugin) =~ /^\//
                    option(:cloudkick_plugin)
                  else
                    File.join(CLOUDKICK_PLUGIN_DIRECTORY, option(:cloudkick_plugin))
                  end
    `#{plugin_path}`
  end

  private

  def check_options
    error 'no cloudkick_plugin option given' unless option(:cloudkick_plugin)
  end
end
