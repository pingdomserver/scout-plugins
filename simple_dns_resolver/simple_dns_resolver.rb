class SimpleDnsResolver < Scout::Plugin
  needs 'resolv'
  needs 'ipaddr'
  OPTIONS=<<-EOS
    nameserver:
      default: 8.8.8.8
    hostname:
      default: google.com
    timeout:
      default: 10
    alert_on_error:
      default: 1
      notes: Generate an alert if there is an error resolving the address. Set to 0 to disable alerts.
      attributes: advanced
  EOS

  def build_report
    addr = Resolv::IPv4.create('0.0.0.0')
    begin
      # Only Ruby >= 2.0.0 supports setting a timeout, so use this
      Timeout.timeout(option(:timeout).to_i) do
        resolver = Resolv::DNS.new(:nameserver => [option(:nameserver)])
        addr = resolver.getaddress(option(:hostname))
      end
    rescue Resolv::ResolvError, Resolv::ResolvTimeout, Timeout::Error => err
      report(:resolved => 0, :address => -1.0)
      if option(:alert_on_error) == 1
        alert("Unable to resolve address: #{err}")
      end
    else
      report(:resolved => 1, :address => IPAddr.new(addr.to_s).to_i)
    end
  end
end

