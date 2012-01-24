class MemoryProfiler < Scout::Plugin
  def build_report
    if solaris?
      solaris_memory
    else
      linux_memory
    end   
  end
  
  def linux_memory
    mem_info = {}
    `cat /proc/meminfo`.each_line do |line|
      _, key, value = *line.match(/^(\w+):\s+(\d+)\s/)
      mem_info[key] = value.to_i
    end
    
    # memory info is empty - operating system may not support it (why doesn't an exception get raised earlier on mac osx?)
    if mem_info.empty?
      raise "No such file or directory"
    end
    
    mem_info['MemTotal'] ||= 0
    mem_info['MemFree'] ||= 0
    mem_info['Buffers'] ||= 0
    mem_info['Cached'] ||= 0
    mem_info['SwapTotal'] ||= 0
    mem_info['SwapFree'] ||= 0
    
    mem_total = mem_info['MemTotal'] / 1024
    mem_free = (mem_info['MemFree'] + mem_info['Buffers'] + mem_info['Cached']) / 1024
    mem_used = mem_total - mem_free
    mem_percent_used = (mem_used / mem_total.to_f * 100).to_i

    swap_total = mem_info['SwapTotal'] / 1024
    swap_free = mem_info['SwapFree'] / 1024
    swap_used = swap_total - swap_free
    unless swap_total == 0    
      swap_percent_used = (swap_used / swap_total.to_f * 100).to_i
    end
    
    # will be passed at the end to report to Scout
    report_data = Hash.new

    report_data['Memory Total'] = mem_total
    report_data['Memory Used'] = mem_used
    report_data['% Memory Used'] = mem_percent_used

    report_data['Swap Total'] = swap_total
    report_data['Swap Used'] = swap_used
    unless  swap_total == 0   
      report_data['% Swap Used'] = swap_percent_used
    end
    report(report_data)
        
  rescue Exception => e
    if e.message =~ /No such file or directory/
      error('Unable to find /proc/meminfo',%Q(Unable to find /proc/meminfo. Please ensure your operationg system supports procfs:
         http://en.wikipedia.org/wiki/Procfs)
      )
    else
      raise
    end
  end
  
  # Memory Used and Swap Used come from the prstat command. 
  # Memory Total comes from prtconf
  # Swap Total comes from swap -s
  def solaris_memory
    report_data = Hash.new
    
    prstat = `prstat -c -Z 1 1`
    prstat =~ /(ZONEID[^\n]*)\n(.*)/
    values = $2.split(' ')

    report_data['Memory Used'] = clean_value(values[3])
    report_data['Swap Used']   = clean_value(values[2])
    
    prtconf = `/usr/sbin/prtconf | grep Memory`    
    
    prtconf =~ /\d+/
    report_data['Memory Total'] = $&.to_i
    report_data['% Memory Used'] = (report_data['Memory Used'] / report_data['Memory Total'].to_f * 100).to_i
    
    swap = `swap -s`
    swap =~ /\d+[a-zA-Z]\sused/
    swap_used = clean_value($&)
    swap =~ /\d+[a-zA-Z]\savailable/
    swap_available = clean_value($&)
    report_data['Swap Total'] = swap_used+swap_available
    unless report_data['Swap Total'] == 0   
      report_data['% Swap Used'] = (report_data['Swap Used'] / report_data['Swap Total'].to_f * 100).to_i      
    end
    
    report(report_data)
  end
  
  # True if on solaris. Only checked on the first run (assumes OS does not change).
  def solaris?
    solaris = if @memory.has_key?(:solaris)
                memory(:solaris) || false
              else
                solaris = false
                begin
                  solaris = true if `uname` =~ /sun/i
                rescue
                end
              end
    remember(:solaris, solaris)
    return solaris
  end
  
  # Ensures solaris memory metrics are in MB. Metrics that don't contain 'T,G,M,or K' are just
  # turned into integers.
   def clean_value(value)
     value = if value =~ /G/i
       (value.to_f*1024.to_f)
     elsif value =~ /M/i
       value.to_f
     elsif value =~ /K/i
       (value.to_f/1024.to_f)
     elsif value =~ /T/i
       (value.to_f*1024.to_f*1024.to_f)
     else
       value.to_f
     end
     ("%.1f" % [value]).to_f
   end
end
