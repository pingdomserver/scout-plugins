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
      notes: A comma separated list of varnishstat metrics.
    path:
      name: Varnish Path
      default:
      notes: Locations to find varnishstat if it's not on the path.

  EOS

  RATE = :second # counter metrics are reported per-second

  def build_report
    stats = {}
    varnishstat_executable = option(:path).blank? ? "varnishstat" : File.join(option(:path), "varnishstat")
    res = `#{varnishstat_executable} -1 2>&1`
    if !$?.success?
      return error("Unable to fetch stats",res)
    end
    res.each_line do |line|
      #client_conn 211980 0.30 Client connections accepted
      next unless /^(\w+)\s+(\d+)\s+(\d+\.\d+)\s(.+)$/.match(line)
      stats[$1.to_sym] = $2.to_i
    end

    total = stats[:cache_miss] + stats[:cache_hit] + stats[:cache_hitpass]
    hitrate = stats[:cache_hit].to_f / (total.nonzero? || 1) * 100
    report(:hitrate => hitrate)

    option(:metrics).split(/,\s*/).compact.each do |metric|
      metric = metric.to_sym
      if stats[metric]
        counter(metric, stats[metric], :per=>RATE)
      else
        error("No such metric - #{metric}")
      end
    end
  end
end
