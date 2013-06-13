class CephPlugin < Scout::Plugin
  
  class CephStatus
  
    HEALTH_OK_STRING = "HEALTH_OK"
    HEALTH_OK = 1
    UNHEALTHY = 0
  
    def initialize(status)
      @status_text = status
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
  
  def new_ceph_status
    CephStatus.new(`ceph -s`.chomp)
  end
  
  def build_report
    report(new_ceph_status.to_h)
  end
  
end