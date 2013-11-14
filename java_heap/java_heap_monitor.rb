class JavaHeapMonitor < Scout::Plugin

  OPTIONS=<<-EOS
    jmap_absolute_path:
      default: /data/dist/jdk1.6.0_37/bin/jmap
      notes: "i.e. /usr/bin/jmap"
  EOS

  def build_report
    begin
      report(:heap => heap_size)
    rescue StandardError => trouble
      error "#{trouble} #{trouble.backtrace}"
    end
  end

  def heap_size
     # pid of java process. assumes only 1 java process
     pid = `ps -eaf | grep java | grep -v grep | grep -v java_heap | awk '{print $2}'`
     # histo output of jmap, which loses all the newlines.  not sure why
     histo = `#{option(:jmap_absolute_path)} -histo:live #{pid} `
     # parse out last line with total instance count and heap size in bytes
     count_size = histo.split('Total', 2)[1]
     # only return the heap size
     size = count_size.split(' ')[1]
     #`echo hi > /tmp/heap.out`
     return size.chomp.to_f / 1024 / 1024 # return mb
   end
end