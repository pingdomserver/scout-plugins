class SentryStats < Scout::Plugin
  needs 'json'
  needs "net/https"
  needs "uri"


  OPTIONS = <<-EOF
    organization_slug:
      name: Organization slug
      notes: Find this in the Sentry API documentation
    api_key:
      name: Your Sentry API key
      notes: This plugin uses basic authorization
  EOF

  def build_report
    start_time = memory(:last_run_time) || Time.now.to_i-60
    number_of_failed_api_calls = memory(:number_of_failed_api_calls).to_i
    report_data = {}
    %w(received rejected blacklisted).each do |stat|
      begin
        # Make the https request w/basic auth via net/https
        response_body=nil
        uri = URI.parse("https://app.getsentry.com/api/0/organizations/#{option(:organization_slug)}/stats/?stat=#{stat}&since=#{start_time}&until=#{Time.now.to_i}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(uri.request_uri)
        request.basic_auth option(:api_key),nil
        response = http.request(request)
        response_body = response.body

        if response.is_a? Net::HTTPSuccess
          data = JSON.parse(response_body)
          res = data.inject(0){|m, e| m += e[1]; m}
          report_data[stat.to_sym] = res
          number_of_failed_api_calls = 0
        else
          report_data[stat.to_sym] = nil
        end
      rescue Exception => e
        # sometimes the sentry API is slow. If it times out, return nil. Create an error if you get this multiple of these in a row
        report_data[stat.to_sym] = nil
        number_of_failed_api_calls +=1
        if number_of_failed_api_calls % 9 == 0
          error("Persistent failure retrieving stats from Sentry with response res=#{response_body}: #{e}")
        end
      end
    end
    remember(:last_run_time, Time.now.to_i)
    remember(:number_of_failed_api_calls, number_of_failed_api_calls)
    report(report_data)
  end

end
