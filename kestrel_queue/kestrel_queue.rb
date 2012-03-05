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
    report :items => gauge_stat(:items), :open_transacitons => gauge_stat(:open_transactions),
      :mem_items => gauge_stat(:mem_items), :age => gauge_stat(:age_msec).to_f / 1000,
      :waiters => gauge_stat(:waiters)
      
    counter(:item_rate, counter_stat(:total_items), :per => :second)
  end

  def counter_stat(stat)
    stats['counters']["q/#{option(:queue)}/#{stat.to_s}"]
  end

  def gauge_stat(stat)
    stats['gauges']["q/#{option(:queue)}/#{stat.to_s}"]
  end
  
  def stats
    @stats ||= JSON.parse(open("http://#{option(:host)}:#{option(:port)}/admin/stats").read)
  end
end
