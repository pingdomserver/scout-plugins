# =================================================================================
# mdstat
# 
# Created by Mark Hasse on 2008-04-15.
# =================================================================================
class MdStat < Scout::Plugin

  OPTIONS = <<-EOS
    monitor_multiple:
      label: Monitor Multiple Arrays
      notes: by default, this plugin only monitors the first/only RAID array it encounters in mdstat. Enter 'true' to monitor all reporting arrays.
      default: false
  EOS
  
  def build_report
    data = Hash.new
         
    full_response = %x(cat /proc/mdstat)
    stripped_response = full_response.chop.split(/\n/)[1..-2].join("\n") # strip off the first and last lines
    mdstat_arrays = stripped_response.split(/\n\n/)
    mdstat_arrays = Array(mdstat_arrays.first) unless(option(:monitor_multiple) == 'true')

    data[:active_disks] = 0
    data[:spares] = 0
    data[:failed_disks] = 0
    
    mdstat_arrays.each do |mdstat|
      mdstat_lines = mdstat.split(/\n/)
      spares = mdstat_lines[0].scan(/\(S\)/).size
      failed = mdstat_lines[0].scan(/\(F\)/).size

      mdstat_lines[1] =~ /\[(\d*\/\d*)\].*\[(.+)\]/
      counts = $1
      if counts.nil?
        error("Not applicable for RAID 0", "This plugin reports the number of active disks, spares, and failed disks. As RAID 0 isn't redundent, a single drive failure destroys the Array. These metrics aren't applicable for RAID 0.")
        next
      end
      status = $2
      
      disk_counts = counts.split('/').map { |x| x.to_i } 
      disk_status = status.squeeze
      
      if disk_counts[0].class == Fixnum && disk_counts[1].class == Fixnum
        data[:active_disks] += disk_counts[0]
        data[:spares]       += spares
        data[:failed_disks] += failed
      else
        raise "Unexpected mdstat file format"
      end 
      
      if disk_counts[0] != disk_counts[1] || disk_status != 'U' || failed > 0 
        if memory(:mdstat_ok)
          remember(:mdstat_ok,false)
          alert(:subject => 'Disk failure detected')
        end
      else
        remember(:mdstat_ok,true)
      end
    end
    report(data)
  end
end

