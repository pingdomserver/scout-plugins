# =================================================================================
# Varnish
#
# Created by Erik Wickstrom on 2011-08-23.
# Updated by Joshua Tuberville on 2012-08-29.
# =================================================================================

class Varnish < Scout::Plugin
  OPTIONS=<<-EOS
    metrics:
      name: Varnishstat Metrics
      default: client_conn,client_req,cache_hit,cache_hitpass,cache_miss,backend_conn,backend_fail
      notes: A comma separated list varnishstat metrics.
    rate:
      name: Metric Reporting Rate
      default: second
      notes: Whether the metrics should be report per second or minute
  EOS

  def build_report
    stats = {}
    `varnishstat -1`.each_line do |line|
      #client_conn 211980 0.30 Client connections accepted
      next unless /^(\w+)\s+(\d+)\s+(\d+\.\d+)\s(.+)$/.match(line)
      stats[$1.to_sym] = $2.to_i
    end

    total = stats[:cache_miss] + stats[:cache_hit] + stats[:cache_hitpass]
    hitrate = stats[:cache_hit].to_f / total * 100
    report(:hitrate => hitrate)

    rate = option(:rate)
    if rate == "second" || rate == "minute"
      rate = rate.to_sym
    else
      error("Invalid rate - #{rate} - using second")
      rate = :second
    end

    option(:metrics).split(/,\s*/).compact.each do |metric|
      metric = metric.to_sym
      if stats[metric]
        counter(metric, stats[metric], :per=>rate)
      else
        error("No such metric - #{metric}")
      end
    end
  end
end