# Created by John Wood of Signal
class CouchDBOverallMonitoring< Scout::Plugin
  OPTIONS = <<-EOS
      couchdb_port:
        notes: The port that CouchDB is running on
        default: 5984
      couchdb_host:
        notes: The host that CouchDB is running on
        default: http://127.0.0.1
    EOS

    needs 'open-uri', 'json', 'facets'

    # Metrics are grouped under the +keys+ below in the +_stats+ output. 
    # http://wiki.apache.org/couchdb/Runtime_Statistics
    METRICS = {'couchdb' => %w{database_reads database_writes},
               'httpd_request_methods' => %w{GET POST PUT DELETE},
               'httpd' => %w{requests view_reads}
              }
    
    # Instead of returning the rate for each status code, we group by 
    # +success+ and +error+ codes.          
    HTTP_STATUS_CODES = {
      'success' => %w{200 201 202 301 304},
      'error'   => %w{400 401 403 404 405 409 412 500}
    }
    
    def build_report
      if option(:couchdb_host).nil? or option(:couchdb_port).nil?
        return error("Please provide the host & port", "The Couch DB Host and Port is required.\n\nCouch DB Host: #{option(:couchdb_host)}\n\nCouch DB Port: #{option(:couchdb_port)}")
      end
      @base_url = "#{option(:couchdb_host)}:#{option(:couchdb_port)}/"
      @response = JSON.parse(open(@base_url + "_stats").read)

      report_metrics
      report_httpd_status_codes
    rescue OpenURI::HTTPError
      error("Stats URL not found","Please ensure the base url for Couch DB Stats is correct. Current URL: \n\n#{@base_url}")
    rescue SocketError
      error("Hostname is invalid","Please ensure the Couch DB Host is correct - the host could not be found. Current URL: \n\n#{@base_url}")
    end
    
    # Parses the _stats output, reporting counters for each of the defined metrics.
    def report_metrics
      METRICS.each do |group,metrics|
        metrics.each do |metric|
          next if @response[group].nil?
          count = @response[group][metric].ergo['current'] || 0
          counter(metric,count.to_i,:per => :second)
        end
      end
    end
    
    # Parses the _stats report_httpd_status_codes group output, 
    # reporting counters for success and error responses.
    def report_httpd_status_codes
      success_count = 0
      error_count   = 0
      group = 'httpd_status_codes'
      
      if !@response[group].nil?     
        HTTP_STATUS_CODES['success'].each do |status_code|
          count = @response[group][status_code].ergo['current'] || 0
          success_count += count
        end
      
        HTTP_STATUS_CODES['error'].each do |status_code|
          count = @response[group][status_code].ergo['current'] || 0
          error_count += count
        end  
      end
      
      counter('httpd_success',success_count,:per => :second)
      counter('httpd_error',error_count,:per => :second) 
    end
    
end