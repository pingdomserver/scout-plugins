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
  # Doesn't work :(
  TIMEOUT=77

  def build_report
    resolver = Resolv::DNS.new(:nameserver => [option(:nameserver)])

    # Only Ruby >= 2.0.0 supports setting a timeout.
    # Without this DNS timeouts will raise a PluginTimeoutError
    if resolver.respond_to? :timeouts=
      resolver.timeouts = option(:timeout)
    end

    begin
      resolver.getaddress(option(:resolve_address))
    rescue Resolv::ResolvError, Resolv::ResolvTimeout => err
      report(:resolved? => 0, :result => err)
    else
      report(:resolved? => 1)
    end
  end
end

