# Created by Doug Barth. 
# http://github.com/dougbarth/
class RabbitmqQueueDetails < Scout::Plugin
  OPTIONS = <<-EOS
  rabbitmqctl:
    name: rabbitmqctl command
    notes: The command used to run the rabbitctl program, minus arguments
    default: rabbitmqctl
  queue:
    name: Queue
    notes: The name of the queue to collect detailed metrics for
  vhost:
    name: Virtual host
    notes: The name of the virtual host to collect detailed metrics for
    default: /
  EOS

  QUEUE_INFO_ITEMS = %w(name messages_ready messages_unacknowledged messages consumers memory)

  def build_report
    rabbitmqctl_script = option('rabbitmqctl')
    queue_name = option('queue')
    vhost = option('vhost')

    unless queue_name
      error("Queue name not specified", "You must specify the queue to get details for.")
      return
    end

    queue_stats_line = get_queue_stats_line(rabbitmqctl_script, queue_name, vhost)

    unless queue_stats_line
      error("\"#{queue_name}\" queue not found", "Please check the queue name for potential errors.")
      return
    end

    report(extract_stats(queue_stats_line))
  end

  def `(command)
    result = super(%{#{command} 2>&1})
    if ($? != 0)
      raise "#{command} exited with a non-zero value: #{$?} `#{result}'"
    end
    result
  end

  private
    def get_queue_stats_line(rabbitmqctl_script, queue_name, vhost)
      cmd = vhost.nil? ? "#{rabbitmqctl_script} -q list_queues " : "#{rabbitmqctl_script} -q list_queues -p '#{vhost}' "
      all_queue_stats = `#{cmd} #{QUEUE_INFO_ITEMS.join(' ')}`.lines.to_a
      all_queue_stats.detect do |line|
        line.split[0] == queue_name
      end
    end

    def extract_stats(queue_stats_line)
      queue_stats = queue_stats_line.split

      report_data = {}
      QUEUE_INFO_ITEMS.each_with_index do |item, i|
        next if item == 'name'
        report_data[item] = queue_stats[i]

        if item == 'memory'
          # Convert from bytes to megabytes
          report_data[item] = report_data[item].to_f / (1024 * 1024)
        end
        if item == 'consumers'
          report_data['no_consumers'] = (report_data[item].to_i == 0 ? 1 : 0)
        end
      end
      report_data
    end
end
