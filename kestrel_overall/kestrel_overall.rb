#
# Created by Eric Lindvall <eric@sevenscale.com>
#

class KestrelOverallMonitor < Scout::Plugin
  OPTIONS=<<-EOS
    host:
      label: Host
      notes: Kestrel host
      default: localhost
    port:
      label: Port
      notes: Kestrel admin HTTP port
      default: 2223
  EOS

  needs 'open-uri'
  needs 'json'

  def build_report
    counter 'data_read_per_second',    counter_stat(:bytes_read) / 1024.0, :per => :second
    counter 'data_written_per_second', counter_stat(:bytes_written) / 1024.0, :per => :second
    counter 'gets_per_second',         counter_stat(:cmd_get), :per => :second
    counter 'peeks_per_second',        counter_stat(:cmd_peek), :per => :second
    counter 'sets_per_second',         counter_stat(:cmd_set), :per => :second
    counter 'hits_per_second',         counter_stat(:get_hits), :per => :second
    counter 'misses_per_second',       counter_stat(:get_misses), :per => :second
    counter 'connections_per_second',  counter_stat(:total_connections), :per => :second
    counter 'items_per_second',        counter_stat(:total_items), :per => :second
    
    report 'connections' => gauge_stat(:connections)
    report 'items' => gauge_stat(:items)
    report 'jvm_heap_used' => gauge_stat(:jvm_heap_used) / 1024.0 / 1024.0
    report 'jvm_heap_max' => gauge_stat(:jvm_heap_max) / 1024.0 / 1024.0
  end

  def counter_stat(stat)
    stats['counters'][stat.to_s].to_f
  end

  def gauge_stat(stat)
    stats['gauges'][stat.to_s].to_f
  end

  def stats
    @stats ||= JSON.parse(open("http://#{option(:host)}:#{option(:port)}/admin/stats").read)
  end
end
