require 'resolv'

class NameResolver < Scout::Plugin
  OPTIONS=<<-EOS
    nameserver:
      default: 8.8.8.8
    resolve_address:
      default: google.com
  EOS

  def build_report
    resolver = Resolv::DNS.new(:nameserver => [option(:nameserver)])

    begin
      result = resolver.getaddress(option(:resolve_address))
    rescue Resolv::ResolvError => err
      alert('Failed to resolve', err)
    end
  end
end

