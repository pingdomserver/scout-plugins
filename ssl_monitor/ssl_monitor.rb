#
# Scout Plugin: ssl_monitor
#
# Copyright 2013, Enrico Stahn <mail@enricostahn.com>
# Copyright 2013, Zanui <engineering@zanui.com.au>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class SslMonitor < Scout::Plugin
  needs 'shellwords'

  OPTIONS = <<-EOS
    domain:
      name: Domain
      default: www.google.com
      notes: Domain to monitor
    port:
      name: Port
      default: 443
      notes: Port to monitor
    sni_name:
      default: nil
      notes: When connecting to a server using SNI, specify the domain name here
      attributes: advanced
  EOS

  def build_report
    unless openssl_bin_exists?
      return error('OpenSSL binary not found.', 'Please install openssl on your monitoring server.')
    end

    end_date = fetch_certificate_end_date(option(:domain), option(:port))
    if end_date.nil?
      return error('End date not found', 'No end date for the specified domain and port found.')
    end

    days_left = (Date.parse(end_date) - Date.today).to_i

    report(:days_left => days_left)
  end

  def cmd_which_openssl
    `which openssl`.split(/\n/).first
  end

  def openssl_bin_exists?
    !cmd_which_openssl.empty?
  end

  def cmd_certificate_end_date(domain, port)
    uri = "#{domain}:#{port}"
    servername_opt= option(:sni_name) ? "-servername #{Shellwords.escape(options(sni_name))}" : ""
    `echo "QUIT" | openssl s_client -connect #{Shellwords.escape(uri)} #{servername_opt} 2> /dev/null | openssl x509 -noout -enddate 2> /dev/null`.split(/\n/).first
  end

  def fetch_certificate_end_date(domain, port)
    date = cmd_certificate_end_date(domain, port)
    date.nil? || !date.include?('notAfter=') ? nil : date.gsub('notAfter=', '')
  end
end
