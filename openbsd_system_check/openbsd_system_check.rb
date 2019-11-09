# Plugin for OpenBSD system metrics. We capture CPU, Memory, Disk, IO and Network statistics.
# OPS-7364: Adding monitoring to OpenBSD Edge servers


class OpenBSD_System_Check < Scout::Plugin

  OPTIONS = <<-EOS
      frequency:
          name: integer value of how many minutes to wait between queries
          default: 2
  EOS

  def network_statics
  interfaces = 'ls /etc/hostname.* | awk -F"hostname." \'{print $2}\''
  int_list = `#{interfaces}`
  int_lists = int_list.split(/\n/)

  int_lists.each do |int|
    next if int.to_s =~ /pfsync|pflog/
    cmd = "ifconfig #{int} | grep -e \"status\" -e \"description\" -e \"inet\""
    stats = `#{cmd}`
    next unless stats.to_s =~ /inet/
    h = {}
    (v,k,x) =
    stats.split(/\n/).each do |x|
      x = x.squeeze('\t').strip
      k,v = x.split(': ')
      h[k] ||= []
      h[k].push(v)
    end
    desc = h["description"]
    stat = h["status"]
    hostname = Socket.gethostname

    @network_status = {}

    if  stat.to_s =~ /active|master|invalid/
      rep = "Interface #{int} is UP"
      report(rep)
      report @network_status["int"] = 1
    elsif stat.to_s =~ /"no carrier"/
      rep = "Interface #{int} is in DOWN state"
      report(rep)
      report @network_status["int"] = 0
      alert("Interface #{int} is DOWN on server #{hostname}", 
        "Please check interface #{int} on #{hostname}; Edge server details are available at wiki https://wiki.myshn.net/pages/viewpage.action?spaceKey=devops&title=POP+architecture")
   else
      rep = "Interface #{int} is in UNKNOWN state"
      report(rep)
      report @network_status["int"] = -1
   end
   end

 end


=begin
    cmd = %x(systat -b ifstat 2> /dev/null)
    op = cmd.to_s.split("\n").grep(/[a-z]+\d{1}.*?$/m)
    @nw_status = {}
    for i in 0..op.length
      int =  op[i].to_s.split("\s")[0]
      int_status = op[i].to_s.split("\s")[1].to_s.split(/[:,\s]/)[0]
      int_connected = op[i].to_s.split("\s")[1].to_s.split(/[:,\s]/)[1]
      if ( int_status == "up" )
         int_sts = 1
      elsif ( int_status == "dn" )
         int_sts = 0
      elsif ( int_status.nil?)
        int_sts = nil
      else
        int_sts = -1
      end
      @nw_status[int] = int_sts
    end
    @nw_status.delete_if { |k, v| v.nil? }
    return @nw_status
=end


  def cpu_percentage
    cmd = %x(systat -b cpu 2> /dev/null)
    op = cmd.to_s.split("\n").grep(/%/)
    @cpu_total = {}
    (@user_cpu_total,@system_cpu_total,@idle_cpu_total)=[0,0,0]
    for i in 0..op.length
      (user_cpu,system_cpu,idle_cpu) = op[i].to_s.split("\s").values_at(1,3,5)
      next if user_cpu.nil?
      usr_cpu = user_cpu.split("%")[0].to_f
      @user_cpu_total += usr_cpu
      sys_cpu = system_cpu.split("%")[0].to_f
      @system_cpu_total += sys_cpu
      idl_cpu = idle_cpu.split("%")[0].to_f
      @idle_cpu_total += idl_cpu
    end
    @cpu_total = { :user_cpu => "#@user_cpu_total", :system_cpu => "#@system_cpu_total", :idle_cpu => "#@idle_cpu_total" }
    return @cpu_total
  end

  def cpu_load
    cmd = %x(uptime 2> /dev/null)
    @cpu_load = {}
    average_5_min_load = cmd.chomp.to_s.split("load averages:").values_at(1).to_s.split(", ")[1]
    @cpu_load["cpu_load"] = average_5_min_load
    return @cpu_load
  end

  def memory_usage
    @memory = {}
    cmd_1 = %x(top -d 1 | grep -i mem 2> /dev/null)
    cmd_2 = %x(sysctl hw | egrep 'hw.(phys|user|real)' 2> /dev/null)
    op_free = cmd_1.to_s.split("Free: ")[1].split(" ")[0]
    op_cache = cmd_1.to_s.split("Cache: ")[1].split(" ")[0]
    op_swap = cmd_1.to_s.split("Swap: ")[1].split("\n")[0]
    op_real = cmd_2.to_s.split("\n")
    (free, suffix_free) = /(\d+)([A-Za-z])/.match(op_free)[1,2]
    (cache, suffix_cache) = /(\d+)([A-Za-z])/.match(op_cache)[1,2]
    (swap, suffix_swap, swap_total, suffix_swap_total) = /(\d+)([A-Za-z])\/(\d+)([A-Za-z])/.match(op_swap)[1,4]
    #(swap, suffix_swap) = /(\d+)([A-Za-z])/.match(op_swap)[1,2]
    real_mem = op_real[1].split("=")[1].to_f
    free = free.to_f
    swap = swap.to_f
    swap_total = swap_total.to_f
    cache = cache.to_f
    def mem_bytes ( memory, suffix )
    if suffix =~ /M|m/
      memory *= 1000000
    elsif suffix =~ /K|k/
      memory *= 1000
    elsif suffix =~ /G|g/
      memory *= 1000000000
    else
      memory
    end
    return memory
    end
    @memory["free_memory"] = mem_bytes(free,suffix_free)
    @memory["cache_memory"] = mem_bytes(cache,suffix_cache)
    @memory["total_free"] = @memory["free_memory"] + @memory["cache_memory"]

    @memory["real_memory"] = real_mem
    @memory["memory_percentage"] = ((@memory["total_free"]/@memory["real_memory"]) * 100).round(2)
    @memory["swap_memory"] = mem_bytes(swap,suffix_swap)
    @memory["swap_total"] = mem_bytes(swap_total,suffix_swap_total)
    @memory["swap_percentage"] = ((@memory["swap_memory"]/@memory["swap_total"]) * 100).round(2)

    return @memory
  end

  def disk_usage
    @capacity = {}
    cmd = %x( df -h | grep '/dev/' 2> /dev/null )
    op = cmd.to_s.split("\n")
    op.each do |l|
      (disk,cap) = l.to_s.split("\s").values_at(5,4)
      @capacity[disk] = cap
    end
    return @capacity

  end

  def iostat_usage
    @iostat = {}
    @iostat_read = {}
    @iostat_write = {}
    cmd = %x( systat -b iostat )
    cmd.split(/\n/).each do |x|
      x = x.squeeze('\t').strip
      next unless x =~ /^[a-z]{2}\d{1}/
      (disk,rps,wps) = x.to_s.split("\s").values_at(0,3,4)
      @iostat_read["iorps_#{disk}"] = rps
      @iostat_write["iowps_#{disk}"] = wps
    end
    @iostat =  @iostat_read.merge(@iostat_write)
    return @iostat
  end




  def build_report
      freq = option(:frequency).to_i
      timer_val = 0
      if !memory(:timer) || ((memory(:timer) % freq) == 0)
            hostname = Socket.gethostname
            report(memory_usage)
            report(cpu_load)
            report(cpu_percentage)
            report(network_statics)
            report(disk_usage)
            report(iostat_usage)
       else
           timer_val = memory(:timer)
       end
      timer_val += 1
      remember(:timer, timer_val)
  end
end