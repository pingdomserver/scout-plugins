class UWSGIMonitoring < Scout::Plugin
    needs 'json'

    OPTIONS=<<-EOS
        location:
            name: Status location
            default: "127.0.0.1:1717"
    EOS

    def build_report
        location = option(:location) 
        hostname, port = location.split(':')

        s = TCPSocket.open(hostname, port.to_i)
        data = JSON.parse(s.read)
        process_uwsgi_stats(data)
    end

    def process_uwsgi_stats(data)
        total_requests = 0
        total_avg_rt = 0
        total_rss = 0
        total_vsz = 0

        data['workers'].each { |worker| 
            total_requests += worker['requests']
            total_avg_rt += worker['avg_rt'] # ms
            total_rss += worker['rss'] # bytes
            total_vsz += worker['vsz'] # bytes
        }

        counter(:requests_per_sec, total_requests, :per => :second)
        report(
            :workers => data['workers'].length,
            :avg_rt => (total_avg_rt / data['workers'].length) / 1000,
            :rss => to_mb(total_rss),
            :vsz => to_mb(total_vsz)
        )
      rescue Errno::ECONNREFUSED
        error("Unable to connect to UWSGI","Unable to fetch stats as the connection to #{location} was refused. Please ensure the host and port are correct.")
    end
    
    # Memory metrics are in bytes
    def to_mb(bytes)
      bytes.to_i / 1024 / 1024
    end
end
