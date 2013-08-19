class NFSThreadsFull < Scout::Plugin

  class NFSThreadSamplingException
  end

  def get_established_nfsd_connections
    connections = `netstat -an | grep 2049 | grep -c ESTABLISHED`.strip
    unless $?.success?
      raise "Failed to get number of NFS network connections"
    end
    connections
  end

  def get_nfsd_thread_status
    nfsd_pids = `ps -ef | grep \[n]fsd\]$ | awk '{print $2}'`.split("\n")
    unless $?.success?
      raise "Failed to get the list of nfsd process ids."
    end
    
    total=0
    running=0
    sleeping=0
    waiting_disk=0
    zombie=0
    trace_or_stop=0
    paging=0
    unknown=0
    nfsd_pids.each do |pid|
      if File.exists?(File.join('/proc',pid,'/status'))
        process_state = `grep ^State #{File.join('/proc',pid,'/status')} | awk '{print $2}'`
        unless $?.success?
          raise NFSThreadSamplingException, process_status
        end

        if process_state =~ /S/
          sleeping += 1
        elsif process_state =~ /R/
          running += 1
        elsif process_state =~ /D/
          waiting_disk += 1
        elsif process_state =~ /Z/
          zombie += 1
        elsif process_state =~ /T/
          trace_or_stop += 1
        elsif process_state =~ /W/
          paging += 1
        else
          unknown += 1
        end
      else
        unknown += 1
      end
      total += 1
    end
    [total, running, sleeping, waiting_disk, zombie, trace_or_stop, paging, unknown]
  end

  def build_report
    nfsd_process_status = get_nfsd_thread_status
    report(
      :total        => nfsd_process_status[0],
      :running      => nfsd_process_status[1],
      :sleeping     => nfsd_process_status[2],
      :waiting_disk => nfsd_process_status[3],
      :zombie       => nfsd_process_status[4],
      :trace_or_stop=> nfsd_process_status[5],
      :paging       => nfsd_process_status[6],
      :unknown      => nfsd_process_status[7],
      :active_nfs_conn => get_established_nfsd_connections)
  end
end

