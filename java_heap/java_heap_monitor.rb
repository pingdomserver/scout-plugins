class JavaHeapMonitor < Scout::Plugin

  OPTIONS=<<-EOS
    jmap_absolute_path:
      notes: "i.e. /usr/bin/jmap"
  EOS

  def build_report
    begin      
      pid = grep_java_process
      histo_output = jmap_histo(pid)
      heap_size = parse_jmap_total(histo_output, pid)
      report(:heap => btye_to_mb(heap_size.to_i)) # return mb
    rescue RuntimeError => trouble
      error "Unexpected issue", "#{trouble}"
    end
  end
 
  def grep_java_process
    # pid of java process. assumes only 1 java process
    pid = `ps -eaf | grep java | grep -v grep | grep -v java_heap | awk '{print $2}'`
    raise "Too many processes.  More than one process was found grepping for java." if pid.lines.count > 1
    raise "No process found grepping for java" if pid.lines.count < 1    
    pid
  end
    
  def jmap_histo(pid)
    non_sudo_jmap = jmap.gsub(/\Asudo /, '')
    raise "jmap executable #{jmap} not found" if !File.exist?(non_sudo_jmap) 
    raise "jmap executable #{jmap} not executable" if(jmap == non_sudo_jmap && !File.executable?(jmap)) # checking if a file is executable does not work w/ sudo
    # histo output of jmap, which loses all the newlines.  not sure why
    histo = `#{jmap} -histo:live #{pid} `
  end
  
  def parse_jmap_total(histo, pid)
    raise "Unexpected jmap output from #{jmap} -histo:live #{pid}.  
      This plugin expects the output of jmap from jdk 1.6.0_37 (and hopefully most others as well)  
      The \'jmap -histo:live\' includes the total heap used in the last line 
      which starts with the string \'Total\'" if histo.index('Total') == nil
    pattern = 'Total'
    # parse out the last line, which should be  Total <count of instances>  <byes of heap used>
    totals_string = histo.split(pattern)[histo.split(pattern).size - 1]
    # split out the two summary counts
    totals_array = totals_string.split(' ')
    raise "unexpected jmap output from #{jmap} -histo:live #{pid}.  
      This plugin expects the output of jmap from jdk 1.6.0_37 (and hopefully most others as well)  
      The \'jmap -histo:live\' includes a summary count of instances and heap used.\'\n
      Instead of two integers, found this: \'#{totals_array}\' " if totals_array.size != 2        
    heap_size = totals_array[1].chomp
    raise  "expected integer. unexpected jmap output from #{jmap} -histo:live #{pid}.
      This plugin expects the output of jmap from jdk 1.6.0_37 (and hopefully most others as well)  
      The \'jmap -histo:live\' includes the total, which should look like \'Total       5081856      493072400\'\n
      Instead, we parsed as the the total heap used is not an integer: \'#{heap_size}\' "   if !a_stringified_integer?(heap_size)
    heap_size
  end

  def a_stringified_integer?(i)
    Integer(i)
    return true
  rescue ArgumentError
    return false
  end
  
  def btye_to_mb(i)
    i.to_f / 1024 / 1024
  end

   def jmap
     option(:jmap_absolute_path) || '/usr/bin/jmap'
   end
end
