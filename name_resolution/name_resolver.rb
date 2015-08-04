class NameResolver < Scout::Plugin
  needs 'resolv'
  OPTIONS=<<-EOS
    nameserver:
      default: 8.8.8.8
    resolve_address:
      default: google.com
  EOS

  def build_report
    resolver = Resolv::DNS.new(:nameserver => [option(:nameserver)])

    begin
      resolver.getaddress(option(:resolve_address))
    rescue Resolv::ResolvError, Resolv::ResolvTimeout => err
      report(:resolved? => 0, :result => err)
    else
      report(:resolved? => 1)
    end
  end
end

