#
# Created by Eric Lindvall <eric@sevenscale.com>
#

class KestrelQueueMonitor < Scout::Plugin
  OPTIONS=<<-EOS
    host:
      label: Host
      notes: Kestrel host
      default: localhost
    port:
      label: Port
      notes: Kestrel admin HTTP port
      default: 2223
    queue:
      label: Queue
      notes: Name of Kestrel queue
  EOS

  needs 'open-uri'
  needs 'json'

  def build_report
    if option(:queue).nil?
      return error("Queue name not provided","Provide the name of the queue you wish to monitor in the plugin settings.")
    elsif gauge_stat(:items).nil? # sanity check - ensure it isn't nil. indication that the queue couldn't be found.
      return error("Queue Not Found: #{option(:queue)}","The queue with name [#{option(:queue)}] could not be found.\n\nCheck to ensure the queue name is correct.")
    end
    
    report :items => gauge_stat(:items), :open_transactions => gauge_stat(:open_transactions),
      :mem_items => gauge_stat(:mem_items), :age => gauge_stat(:age_msec) / 1000,
      :waiters => gauge_stat(:waiters)
      
    counter(:item_rate, counter_stat(:total_items), :per => :second)
  end

  def counter_stat(stat)
    stats['counters']["q/#{option(:queue)}/#{stat.to_s}"].to_f
  end

  def gauge_stat(stat)
    stats['gauges']["q/#{option(:queue)}/#{stat.to_s}"].to_f
  end
  
  def stats
    @stats ||= JSON.parse(open("http://#{option(:host)}:#{option(:port)}/admin/stats").read)
  end
end
