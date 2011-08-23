# =================================================================================
# varnish
# 
# Created by Erik Wickstrom on 2011-08-23.
# =================================================================================

class VarnishPlugin < Scout::Plugin
  def build_report
    stats = {}
    `varnishstat -1`.each_line do |line|
      #client_conn 211980 0.30 Client connections accepted
      next unless /^(\w+)\s+(\d+)\s+(\d+\.\d+)\s(.+)$/.match(line)
      stats[$1.to_sym] = $2.to_i
    end
    report(:hitrate => 1 - (stats[:cache_miss].to_f / stats[:cache_hit]))
    counter(:backend_success, stats[:backend_conn], :per=>:second)
    counter(:backend_fail, stats[:backend_fail], :per=>:second)
    counter(:cache_hit, stats[:cache_hit], :per=>:second)
    counter(:cache_hitpass, stats[:cache_hitpass], :per=>:second)
    counter(:cache_miss, stats[:cache_miss], :per=>:second)
    counter(:client_conn, stats[:client_conn], :per=>:second)
    counter(:client_req, stats[:client_req], :per=>:second)
    counter(:client_req, stats[:client_req], :per=>:second)
  end
end
