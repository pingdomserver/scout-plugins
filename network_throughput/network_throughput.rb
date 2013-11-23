# 
# Created by Eric Lindvall <eric@5stops.com>
#
class NetworkThroughput < Scout::Plugin
  
  OPTIONS=<<-EOS
  interfaces:
    notes: Only interfaces that match the given regular expression will be monitored. The plugin can monitor a maximum of 5 interfaces.
    default: "venet|eth"
    attributes: advanced
  EOS
  
  def build_report
    lines = %x(cat /proc/net/dev).split("\n")[2..-1]
    regex = Regexp.compile(option("interfaces") || /venet|eth/)
    interfaces = []
    found = false
    lines.each do |line|
      iface, rest = line.split(':', 2).collect { |e| e.strip }
      interfaces << iface
      next unless iface =~ regex
      found = true
      cols = rest.split(/\s+/)

      in_bytes, in_packets, in_errs, in_drops, out_bytes, out_packets, out_errs, out_drops = cols.values_at(0, 1, 2, 3, 8, 9, 10, 11).collect { |i| i.to_i }

      counter("#{iface}_in",          in_bytes / 1024.0,  :per => :second, :round => 2)
      counter("#{iface}_in_packets",  in_packets,         :per => :second, :round => 2)
      counter("#{iface}_in_errors",   in_errs,            :per => :second, :round => 2)
      counter("#{iface}_in_drops",    in_drops,           :per => :second, :round => 2)
      counter("#{iface}_out",         out_bytes / 1024.0, :per => :second, :round => 2)
      counter("#{iface}_out_packets", out_packets,        :per => :second, :round => 2)
      counter("#{iface}_out_errors",  out_errs,           :per => :second, :round => 2)
      counter("#{iface}_out_drops",   out_drops,          :per => :second, :round => 2)
    end
    unless found
      error("No interfaces found", "No interfaces were found that matched the regular expression [#{regex}]. You can modify the regular expression in the plugin's advanced settings.\n\nPossible interfaces:\n#{interfaces.join("\n")}")
    end
  rescue Exception => e
    error("#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end
end
