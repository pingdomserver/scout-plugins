$VERBOSE=false
class SSLCertExpiration < Scout::Plugin
  needs 'openssl'

  OPTIONS=<<-EOS
    certs:
      name: SSL Certificates
      notes: Comma separated list of local SSL Certificates.
    ignore_missing:
      name: Ignore Missing Certificates
      notes: Whether or not to ignore missing SSL Certs. Default is true.
      default: true
  EOS

  def build_report
    # fail spectacularly if no certs are passed
    if option(:certs).nil?
      return error("Certs Required", "You did not pass any certs. This is required.")
    end

    # need the current date to compare to the cert
    today = Time.now

    # convert option(:certs) to array and remove certs not found on the filesystem,
    # or fail spectacularly if ignore_missing is set to false.
    if option(:ignore_missing) == "true"
      certs = option(:certs).split(',').delete_if {|f| !File.exist?(f)}
    else
      certs = option(:certs).split(',')
      certs.each do |cert|
        return error("Cert Not Found!", "#{cert} was not found on the filesystem.")
      end
    end

    # loop through the remaining certs and grab their expiration date w/openssl
    certs.each do |c|
      certificate = get_cert_info(c)
      # puts "Your Issuer is bad and you should feel bad." if certificate.issuer.to_s =~ /godaddy/i

      # take not_after from the cert and figure out number of days left
      # note, this errs on the side of caution and rounds down.
      expiration = ((Time.at(certificate.not_after) - Time.at(today)) / 60 / 60 / 24).to_i

      # add cert name and expiration to report
      report(c.split('/').last => expiration)
    end
  end

  def get_cert_info(file)
    return OpenSSL::X509::Certificate.new(File.read(file))
  end
end

