class SlabtopSummary < Scout::Plugin
  OPTIONS=<<-EOS
    directory:
      default: /tmp
      name: Directory
      notes: The directory in which to execute this plugin
  EOS
  def kilobytes_to_bytes(size)
    size.to_i * 1024
  end
  def build_report
    slabtop_header = `cd #{option(:directory)} && sudo slabtop -o | head -n 4 | awk '{print $8" "$10}' | sed -e 's/K//g'`
    lines = slabtop_header.split("\n")
    ( active_objects, total_objects ) = lines[0].split
    ( active_slabs, total_slabs ) = lines[1].split
    ( active_caches, total_caches ) = lines[2].split
    ( active_size, total_size ) = lines[3].split
    report(
      :active_objects => active_objects,
      :active_slabs => active_slabs,
      :active_caches => active_caches,
      :active_size => kilobytes_to_bytes(active_size),
      :total_objects => total_objects,
      :total_slabs => total_slabs,
      :total_caches => total_caches,
      :total_size => kilobytes_to_bytes(total_size),
    )
  end
end
