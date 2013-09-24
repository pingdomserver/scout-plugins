require 'net/http'
require 'uri'

class SolrStatistics < Scout::Plugin
    needs 'json'

    OPTIONS=<<-EOS
        location:
            name: Stats URL
            default: http://localhost:8983/solr/admin/mbeans
        handler:
            name: Query handler to monitor
            default: "/select"
    EOS

    def build_report
        location = option(:location)
        handler = option(:handler)

        uri = URI.parse(location)
        uri.query = 'stats=true&wt=json'
        response = Net::HTTP.get_response(uri)

        data = JSON.parse(response.body)

        stats = {}
        data['solr-mbeans'].each_slice(2).collect.each do |key, value|
            stats[key] = value
        end
        
        result = {
            'numDocs' => stats['CORE']['searcher']['stats']['numDocs'],
            'maxDocs' => stats['CORE']['searcher']['stats']['maxDoc'],
        }

        hstats = stats['QUERYHANDLER'][handler]['stats']
        result = result.merge({
            'avgRequestsPerSecond' => hstats['avgRequestsPerSecond'].to_f,
            '5minRateReqsPerSecond' => hstats['5minRateReqsPerSecond'].to_f,
            '15minRateReqsPerSecond' => hstats['15minRateReqsPerSecond'].to_f,
            'avgTimePerRequest' => hstats['avgTimePerRequest'].to_f,
            'medianRequestTime' => hstats['medianRequestTime'].to_f,
            '95thPcRequestTime' => hstats['95thPcRequestTime'].to_f,
        })

        report(result)
    end
end
