# =================================================================================
# rabbitmq_overall
#
# Created by Erik Wickstrom on 2011-10-14.
# =================================================================================
class RabbitmqQueueDetails < Scout::Plugin
  needs 'json'
  needs 'net/http'
  needs 'cgi'

  OPTIONS=<<-EOS
    management_url:
        default: http://localhost:15672
        notes: The base URL of your RabbitMQ Management server. (Use port 55672 if you are using RabbitMQ older than 3.x)
    username:
        default: guest
    password:
        default: guest
        attributes: password
    queue:
        notes: The name of the queue to collect detailed metrics for
    vhost:
        notes: The virtual host containing the queue.
  EOS

  def build_report
    if option(:queue).nil?
        return error("Queue Required", "Specificy the queue you wish to monitor in the plugin settings.")
    end

    queue = get_queue(option(:vhost), option(:queue))

    if queue["durable"]
        durable = 1
    else
        durable = 0
    end

    report(:messages => queue["messages"],
           :messages_unacknowledged => queue["messages_unacknowledged"],
           :memory => queue["memory"].to_f / (1024 * 1024),
           :pending_acks => queue["backing_queue_status"]["pending_acks"],
           :consumers => queue["consumers"],
           :durable => durable,
           :messages_ready => queue["messages_ready"])
  rescue Errno::ECONNREFUSED
    error("Unable to connect to RabbitMQ Management server", "Please ensure the connection details are correct in the plugin settings.\n\nException: #{$!.message}\n\nBacktrace:\n#{$!.backtrace}")
  end


  def get_queue(vhost, queue)
     url = "#{option('management_url').to_s.strip}/api/queues/#{CGI::escape(vhost)}/#{queue}/"
     result = query_api(url)
  end
  
  def query_api(url)
     parsed = URI.parse(url)
     http = Net::HTTP.new(parsed.host, parsed.port)
     req = Net::HTTP::Get.new(parsed.path)
     req.basic_auth option(:username), option(:password)
     response = http.request(req)
     data = response.body
  
     # we convert the returned JSON data to native Ruby
     # data structure - a hash
     result = JSON.parse(data)
  
     return result
  end
end
