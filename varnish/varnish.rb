# =================================================================================
# Varnish
#
# Created by Erik Wickstrom on 2011-08-23.
# Updated by Joshua Tuberville on 2012-08-29.
# Updated by Matt Chesler on 2015-12-21.
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

  V3_V4_MAP = {
    'client_conn'       => 'MAIN.sess_conn',
    'client_drop'       => 'MAIN.sess_drop'
  }

  def build_report
    stats = {}
    varnishstat_executable = option(:path).to_s.empty? ? "varnishstat" : File.join(option(:path), "varnishstat")
    res = `#{varnishstat_executable} -1 2>&1`
    if !$?.success?
      return error("Unable to fetch stats",res)
    end
    res.each_line do |line|
      #client_conn 211980 0.30 Client connections accepted
      next unless /\A([\.\w]+)\s+(\d+)\s+(\d+\.\d+)\s(.+)\Z/.match(line)
      stats[$1] = $2.to_i
    end

    # support Varnish 3 or 4 keys
    cache_miss = stats['cache_miss'] || stats['MAIN.cache_miss']
    cache_hit = stats['cache_hit'] || stats['MAIN.cache_hit']
    cache_hitpass = stats['cache_hitpass'] || stats['MAIN.cache_hitpass']

    total = cache_miss + cache_hit + cache_hitpass
    hitrate = cache_hit.to_f / (total.nonzero? || 1) * 100
    report(:hitrate => hitrate)

    option(:metrics).split(/,\s*/).compact.each do |metric|
      if stats[metric] || stats["MAIN.#{metric}"] || stats[V3_V4_MAP[metric]]
        counter(metric, stats[metric] || stats["MAIN.#{metric}"] || stats[V3_V4_MAP[metric]], :per=> RATE)
      else
        error("No such metric - #{metric}")
      end
    end
  end
end