require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/ssl_cert_expiration"
require 'time'

class SSLCertExpirationTest < Test::Unit::TestCase

  def test_success
    # create mock object via mocha which will provide 'not_after' method with a timestamp
    fakecert = mock('object')
    fakecert.expects(:not_after).returns(Time.parse("Sat Sep 20 18:12:38 UTC 2014"))

    # fixtures/cert is an empty file
    plugin = SSLCertExpiration.new({},{}, options = {
      :certs => "/foo/bar,#{File.join(File.dirname(__FILE__), "fixtures/cert")}",
      :ignore_missing => "true"
    })

    # stub out `get_cert_info` method for the mock object created above.
    plugin.stubs(:get_cert_info).returns(fakecert)

    # stub out the `today` object for a random date
    plugin.stubs(:today).returns(Time.parse("Fri Mar 7 12:12:12 UTC 2014"))

    result = plugin.run

    assert_equal 226, result[:reports].first['cert']
    assert result[:reports].first.keys.include?('cert')
    assert result[:errors].empty?
  end
end
