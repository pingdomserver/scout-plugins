require 'benchmark'
require 'net/http'
require 'net/https'
require 'uri'

class UrlMonitor < Scout::Plugin
  include Net

  OPTIONS=<<-EOS
  url:
    name: Url
    notes: The full URL (including http://) of the URL to monitor. You can provide basic authentication options as well (http://user:pass@domain.com)
  host_override:
    name: Host Override
    notes: "Override what host to connect to. You can use 'localhost' to monitor this host while still providing a real Host: header"
    attributes: advanced
  timeout_length:
    default: '50'
    name: Timeout Length
    notes: "Seconds to wait until connection is opened."
    attributes: advanced
  EOS

  def build_report
    url = option("url").to_s.strip
    if url.empty?
      return error("A url wasn't provided.", "Please enter a URL to monitor in the plugin settings.")
    end

    unless url =~ %r{\Ahttps?://}
      url = "http://#{url}"
    end

    response = nil
    response_time = Benchmark.realtime do
      response = http_response(url)
    end

    report(:status => response.class.to_s[/^Net::HTTP(.*)$/, 1],
           :response_time => response_time)

    is_up = valid_http_response?(response) ? 1 : 0
    report(:up => is_up)

    if is_up != memory(:was_up)
      if is_up == 0
        alert("The URL #{url} is not responding", unindent(<<-EOF))
            URL: #{url}

            Code: #{response.is_a?(String) ? 'N/A' : response.code}
            Status: #{response.is_a?(String) ? 'N/A' : response.class.to_s[/^Net::HTTP(.*)$/, 1]}
            Message: #{response.is_a?(String) ? response : response.message}
          EOF
        remember(:down_at => Time.now)
      else
        if memory(:was_up) && memory(:down_at)
          alert( "The URL [#{url}] is responding again",
                 "URL: #{url}\n\nStatus: #{response.class.to_s[/^Net::HTTP(.*)$/, 1]}. " +
                 "Was unresponsive for #{(Time.now - memory(:down_at)).to_i} seconds")
        else
          alert( "The URL [#{url}] is responding",
                 "URL: #{url}\n\nStatus: #{response.class.to_s[/^Net::HTTP(.*)$/, 1]}. ")
        end
        memory.delete(:down_at)
      end
    end

    remember(:was_up => is_up)
  rescue Exception => e
    error( "Error monitoring url [#{url}]",
           "#{e.message}<br><br>#{e.backtrace.join('<br>')}" )
  end

  def valid_http_response?(result)
    [HTTPOK,HTTPFound,HTTPServiceUnavailable].include?(result.class)
  end

  # returns the http response from a url
  # CONFUSING: note that the response is a String when an error occurs.
  def http_response(url)
    uri = URI.parse(url)

    response = nil
    retry_url_trailing_slash = true
    retry_url_execution_expired = true
    begin
      connect_host = option('host_override').to_s.strip
      connect_host = uri.host if connect_host.empty?

      http = Net::HTTP.new(connect_host,uri.port)
      http.use_ssl = url =~ %r{\Ahttps://}
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = option('timeout_length').to_i
      http.start(){|h|
            req = Net::HTTP::Head.new((uri.path != '' ? uri.path : '/' ) + (uri.query ? ('?' + uri.query) : ''))
            req['User-Agent'] = "ScoutURLMonitor/#{Scout::VERSION}"
            req['host'] = uri.host
            if uri.user && uri.password
              req.basic_auth uri.user, uri.password
            end
            response = h.request(req)
      }
    rescue Exception => e
      # forgot the trailing slash...add and retry
      if e.message == "HTTP request path is empty" and retry_url_trailing_slash
        url += '/'
        uri = URI.parse(url)
        h = Net::HTTP.new(uri.host)
        retry_url_trailing_slash = false
        retry
      elsif e.message =~ /execution expired/ and retry_url_execution_expired
        retry_url_execution_expired = false
        retry
      else
        response = e.to_s
      end
    end

    return response
  end

  def unindent(string)
    indentation = string[/\A\s*/]
    string.strip.gsub(/^#{indentation}/, "")
  end
end
