class NameResolver < Scout::Plugin
  needs 'resolv'
  OPTIONS=<<-EOS
    nameserver:
      default: 8.8.8.8
    resolve_address:
      default: google.com
    timeout:
      default: 30
  EOS

  def build_report
    begin
      # Only Ruby >= 2.0.0 supports setting a timeout, so use this
      Timeout.timeout(option(:timeout)) do
        resolver = Resolv::DNS.new(:nameserver => [option(:nameserver)])
        resolver.getaddress(option(:resolve_address))
      end
    rescue Resolv::ResolvError, Resolv::ResolvTimeout, Timeout::Error => err
      report(:resolved? => 0, :result => err)
    else
      report(:resolved? => 1)
    end
  end
end

