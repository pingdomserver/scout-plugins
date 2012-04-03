class HaproxyMonitoring < Scout::Plugin

  if RUBY_VERSION < "1.9"
    needs 'fastercsv'
  else
    # typically, avoid require. In this case we can't use needs' deferred loading because we need to alias CSV
    require 'csv'
    FasterCSV=CSV
  end
  needs 'open-uri'

  OPTIONS=<<-EOS
  uri:
    name: URI
    notes: "URI of the haproxy CSV stats url. See the 'CSV Export' link on your haproxy stats page (example stats page: http://demo.1wt.eu/)."
  proxy:
    notes: The name of the proxy to monitor. Proxies are typically listed in the haproxy.cfg file.
  proxy_type:
    notes: If frontend and backend proxies have the same name, you can specify which proxy you want to monitor ('frontend' or 'backend').
    attributes: advanced
  user:
    notes: If protected under basic authentication provide the user name.
  password:
    notes: If protected under basic authentication provide the password.
    attributes: password
  EOS

  def build_report

    if option(:uri).nil?
      return error('URI to HAProxy Stats Required', "It looks like the URI to the HAProxy stats page (in csv format) hasn't been provided. Please enter this URI in the plugin settings.")
    end
    proxy = option(:proxy)
    valid_proxy_types = %w(FRONTEND BACKEND)
    if option(:proxy_type)
      if !%w(BACKEND FRONTEND).include?(option(:proxy_type).upcase)
        return error('Invalid Proxy Type provided', "The proxy type must be either BACKEND or FRONTEND. Current value: #{option(:proxy_type).upcase}")
      else
        valid_proxy_types = [option(:proxy_type).upcase]
      end
    end
    possible_proxies = []
    proxy_found = false
    begin
      FasterCSV.parse(open(option(:uri),:http_basic_authentication => [option(:user),option(:password)]), :headers => true) do |row|
        if valid_proxy_types.include?(row["svname"])
          possible_proxies << row["# pxname"]
          next unless proxy.to_s.strip.downcase == row["# pxname"].downcase

          if proxy_found
            data_for_server[:reports] = []
            data_for_server[:memory] = {}
            return error("Multiple proxies have the name '#{proxy}'","Please specify the proxy type (BACKEND or FRONTEND) in the plugin's advanced settings.")
          else
            proxy_found = true
          end

          counter(:requests,    row['stot'].to_i,  :per => :minute)
          counter(:errors_req,  row['ereq'].to_i,  :per => :minute) if row['ereq']
          counter(:errors_conn, row['econ'].to_i,  :per => :minute) if row['econ']
          counter(:errors_resp, row['eresp'].to_i, :per => :minute) if row['eresp']

          counter(:bytes_in,  row['bin'].to_i,  :per => :second) if row['bin']
          counter(:bytes_out, row['bout'].to_i, :per => :second) if row['bout']

          report(:active_sessions, row['scur'])
          report(:queued_sessions, row['qcur'])

          report(:active_servers, row['act'])

          report(:proxy_up=>%w(UP OPEN).find {|s| s == row['status']} ? 1 : 0)
        end
      end
    rescue OpenURI::HTTPError
      if $!.message == '401 Unauthorized'
        return error("Authentication Failed", "Unable to access the stats page at #{option(:uri)} with the username '#{option(:user)}' and provided password. Please ensure the username, password, and URI are correct.")
      elsif $!.message != '404 Not Found'
        return error("Unable to find the stats page", "The stats page could not be found at: #{option(:uri)}.")
      else
        raise
      end
    rescue FasterCSV::MalformedCSVError
      return error('Unable to access stats page', "The plugin encountered an error attempting to access the stats page (in CSV format) at: #{option(:uri)}. The exception: #{$!.message}\n#{$!.backtrace}")
    end
    if proxy.nil?
      error('Proxy name required',"The name of the proxy to monitor must be provided in the plugin settings. The possible proxies to monitor:\n<ul>#{possible_proxies.map { |p| "<li>#{p}</li>"}.join('')}</ul>")
    elsif !proxy_found
      error('Proxy not found',"The proxy '#{proxy}' was not found. The possible proxies to monitor:\n<ul>#{possible_proxies.map { |p| "<li>#{p}</li>"}.join('')}</ul>")
    end
  end

end
