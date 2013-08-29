class SimplePlugin < Scout::Plugin
    needs 'json'

    OPTIONS=<<-EOS
        location:
            name: Status location
            default: "127.0.0.1:1717"
    EOS

    def build_report
        location = option(:location) || '127.0.0.1:1717'
        hostname, port = location.split(':')

        s = TCPSocket.open(hostname, port.to_i)
        data = JSON.parse(s.read)

        total_requests = 0
        total_avg_rt = 0
        total_rss = 0
        total_vsz = 0

        data['workers'].each { |worker| 
            total_requests += worker['requests']
            total_avg_rt += worker['avg_rt']
            total_rss += worker['rss']
            total_vsz += worker['vsz']
        }

        counter(:requests_per_sec, total_requests, :per => :second)
        report(
            :workers => data['workers'].length,
            :avg_rt => (total_avg_rt / data['workers'].length) / 1000, 
            :rss => total_rss,
            :vsz => total_vsz
        )
    end
end
