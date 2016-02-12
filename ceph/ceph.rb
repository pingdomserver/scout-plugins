class CephPlugin < Scout::Plugin
  
  def build_report
    report(CephStatus.new.to_h)
  rescue StatusError => e
    # Errors contain timestamps, since on the server-side we only count an error as repeating if the body is unique, returning the 
    # raw error message would result in an error every minute.
    #
    # Example Error:
    # An occur occurred trying to fetch ceph status information: 
    # 2016-02-12 12:27:19.267090 7f3aff317700 -1 monclient(hunting): ERROR: missing keyring, cannot use cephx for authentication 
    # 2016-02-12 12:27:19.267098 7f3aff317700 0 librados: client.admin initialization error (2) No such file or directory 
    # Error connecting to cluster: ObjectNotFound
    message = e.message
    matches = message.scan(/(error.+)/i)
    if matches.any?
      error("Unable to fetch status information","Errors occured trying to fetch status information:\n#{matches.map {|m| m.first}}")
    else
      error("Unable to fetch status information","An occur occurred trying to fetch ceph status information. Ensure the scoutd user has permission to fetch status information.")
    end
  end

  # Raised by #CephStatus if an error fetching status output.
  class StatusError < Exception
  end
  
  class CephStatus
  
    HEALTH_OK_STRING = "HEALTH_OK"
    HEALTH_OK = 1
    UNHEALTHY = 0
  
    def initialize(cmd = "ceph -s")
      output = `#{cmd} 2>&1`
      if $? and !$?.success?
        raise StatusError, output
      end
      @status_text = output.chomp
      parse
    end
  
    def parse
      @lines = @status_text.split("\n").map { |line| line.strip }
      @status = {}
      @ceph_health = @lines[0].split(' ')[1]
      @status[:health] = @ceph_health==HEALTH_OK_STRING ? HEALTH_OK : UNHEALTHY
      @unhealthy_reason = @lines[0].split(' ')[2..-1].join(' ') rescue nil
      @status[:num_osds] = @lines[2].match(/(\d*)\sosds:/)[1].to_i
      @status[:osds_up] = @lines[2].match(/(\d*)\sup/)[1].to_i
      @status[:osds_in] = @lines[2].match(/(\d*)\sin/)[1].to_i
      @status[:data_size] = clean_value(@lines[3].match(/\s(\d*\s[A-Z]{2})\sdata/)[1])
      @status[:used] = clean_value(@lines[3].match(/\s(\d*\s[A-Z]{2})\sused/)[1])
      @status[:available] = clean_value(@lines[3].match(/\s(\d*\s[A-Z]{2})\s\//)[1])
      @status[:cluster_total_size] = clean_value(@lines[3].match(/\s(\d*\s[A-Z]{2})\savail/)[1])
      @status[:capacity] = clean_value(((@status[:used].to_f / @status[:cluster_total_size].to_f)*100).round(1))
    end
    
    def clean_value(value)
      value = if value =~ /GB/i
        value.to_f
      elsif value =~ /MB/i
        (value.to_f/1024.to_f)
      elsif value =~ /KB/i
        (value.to_f/1024.to_f/1024.to_f)
      elsif value =~ /TB/i
        (value.to_f*1024.to_f)
      else
        value.to_f
      end
      ("%.1f" % [value]).to_f
    end
    
    def ceph_health
      @ceph_health
    end
    
    def unhealthy_reason
      @unhealthy_reason
    end
  
    def cluster_ok?
      @status[:health] == HEALTH_OK
    end
    
    def to_h
      @status
    end
  
    def method_missing(sym, *args, &block)
      if @status.key?(sym)
        @status[sym]
      else
        super
      end
    end
  
  end
  
end