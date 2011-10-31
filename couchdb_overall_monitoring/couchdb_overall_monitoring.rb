# Created by John Wood of Signal
class CouchDBOverallMonitoring< Scout::Plugin
  OPTIONS = <<-EOS
      couchdb_port:
        notes: The port that CouchDB is running on
        default: 5984
      couchdb_host:
        notes: The host that CouchDB is running on
        default: http://127.0.0.1
      couchdb_user:
        notes: The CouchDB http basic authentication user
        default: admin
      couchdb_pwd:
        notes: The CouchDB http basic authentication password
        default: secret
    EOS

    needs 'open-uri', 'json'

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
      options = {}
      @base_url = "#{option(:couchdb_host)}:#{option(:couchdb_port)}/"
      options[:http_basic_authentication] = [option(:couchdb_user), option(:couchdb_pwd)] if option(:couchdb_user)
      @response = JSON.parse(open(@base_url + "_stats", options).read)

      report_metrics
      report_httpd_status_codes
    rescue OpenURI::HTTPError => e
      if e.message.include? "401 Unauthorized"
        status = "Stats URL access denied"
        msg = "Please ensure the http basic auth user and password is correct. Current URL: \n\n#{@base_url}"
      else
        status = "Stats URL not found"
        msg = "Please ensure the base url for Couch DB Stats is correct. Current URL: \n\n#{@base_url}"
      end
      error(status,msg)
    rescue SocketError
      error("Hostname is invalid","Please ensure the Couch DB Host is correct - the host could not be found. Current URL: \n\n#{@base_url}")
    end
    
    # Parses the _stats output, reporting counters for each of the defined metrics.
    def report_metrics
      METRICS.each do |group,metrics|
        metrics.each do |metric|
          next if @response[group].nil?
          count = fetch_metric(@response[group][metric])
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
          count = fetch_metric(@response[group][status_code])
          success_count += count
        end
      
        HTTP_STATUS_CODES['error'].each do |status_code|
          count = fetch_metric(@response[group][status_code])
          error_count += count
        end  
      end
      
      counter('httpd_success',success_count,:per => :second)
      counter('httpd_error',error_count,:per => :second) 
    end
    
    def fetch_metric(metric)
      val = metric ? metric['current'] : nil
      val || 0
    end
    
end