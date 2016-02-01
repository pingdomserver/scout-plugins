class NetfilterConnTrack < Scout::Plugin
  def build_report
    begin
      conntrack_max_output = `cat /proc/sys/net/netfilter/nf_conntrack_max`
      max = conntrack_max_output.split("\n")[0].to_i

      conntrack_count_output = `cat /proc/sys/net/netfilter/nf_conntrack_count`
      count = conntrack_count_output.split("\n")[0].to_i
    rescue Exception => e
      return error("Error reading procfs data. Is the nf_conntrack module loaded?", "#{e.message}: #{e.backtrace.join('\n')}")
    end

    # Don't divide by 0.
    percent = max > 0 ? (count.to_f / max.to_f) * 100 : 0

    report(:conntrack_count => count, :conntrack_max => max, :conntrack_percent_used => percent)
  end
end

