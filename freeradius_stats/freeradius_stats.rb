#
# A Scout plugin to collect stats from Freeradius
# This plugin requires the Freeradius status server to be enabled. Instructions can be found at:
#    http://wiki.freeradius.org/Status
#
# Created by Clint Nelissen for Sunray <clint@sunraytvi.com>
#

class FreeradiusStats < Scout::Plugin
  OPTIONS=<<-EOS
  host:
    name: Freeradius host
    notes: Specify something other than 'localhost' to connect via TCP
    default: localhost
  port:
    name: Freeradius status port
    notes: Specify the port to connect to the Freeradius status server
    default: 18120
  secret:
    name: Admin secret
    notes: The secret for the admin user, as defined in /etc/raddb/sites-available/status
    default: adminsecret
  EOS

  def build_report
    freeradius_version = Integer(%x(freeradius -v).split(/\n/)[0].scan(/\d+/)[0])

    output = %x(echo "Message-Authenticator = 0x00, FreeRADIUS-Statistics-Type = 1" |
      radclient #{ '-x ' if freeradius_version >= 3 }#{option(:host)}:#{option(:port)} status #{option(:secret)} 2>&1)

    if !$?.success? or output =~ /no response/i
      # If the port was up last run, but not this run, report an error (cuts down on alerts)
      if memory(:portStatus) == 1
        error("Could not connect to Freeradius status server on #{option(:host)}:#{option(:port)}", "Command Result:\n\n#{output}")
      end

      # Set the port status to down for the next run
      remember(:portStatus => 0)
    else
      lines = output.split(/\n/)

      # Filter out lines that are not important
      lines = lines.grep(Regexp.new(/FreeRADIUS-Total/))

      access_requests = lines[0].split(' = ')[1].to_i
      access_accepts = lines[1].split(' = ')[1].to_i
      access_rejects = lines[2].split(' = ')[1].to_i
      access_challenges = lines[3].split(' = ')[1].to_i
      auth_responses = lines[4].split(' = ')[1].to_i
      duplicate_requests = lines[5].split(' = ')[1].to_i
      malformed_requests = lines[6].split(' = ')[1].to_i
      invalid_requests = lines[7].split(' = ')[1].to_i
      dropped_requests = lines[8].split(' = ')[1].to_i
      unknown_types = lines[9].split(' = ')[1].to_i

      counter(:access_requests, access_requests, :per => :minute)
      counter(:access_accepts, access_accepts, :per => :minute)
      counter(:access_rejects, access_rejects, :per => :minute)
      counter(:access_challenges, access_challenges, :per => :minute)
      counter(:auth_responses, auth_responses, :per => :minute)
      counter(:duplicate_requests, duplicate_requests, :per => :minute)
      counter(:malformed_requests, malformed_requests, :per => :minute)
      counter(:invalid_requests, invalid_requests, :per => :minute)
      counter(:dropped_requests, dropped_requests, :per => :minute)
      counter(:unknown_types, unknown_types, :per => :minute)

      # Set the port status to up for the next run
      remember(:portStatus => 1)
    end
  end
end
