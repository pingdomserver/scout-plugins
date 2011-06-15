# A plugin to provide Tungsten monitoring for Scout.
# Written by Ben Somers & funded by BookRenter.com
# It primarily gets its data by running the scripts provided by Continuent for Nagios monitoring,
# but also directly queries Tungsten's 'cctrl' utility for information not available via those scripts.
# There is an additional script that may be useful, check_tungsten_services -rc, but it requires sudo
# to execute.  That appears to be the only way to get information on the health of the Tungsten connector.
# options:
#   dr_only: Short for "Data Replication Only".  For use on a backup cluster, the only difference is that
#     this expects that all datasources are OFFLINE.  With dr_only on, the expectation is that
#     all datasources are ONLINE.  No difference to other services.

class TungstenPlugin < Scout::Plugin
  attr_accessor :datasources

  OPTIONS = <<-EOS
  dr_only:
    name: Data Replication Only
    notes: For read-only databases (e.g. all-slave cluster); leave blank for main cluster
  EOS

  def parse_datasources(datasources_string)
    datasources_string.split(/\|\n\|/).inject({}) do |datasources, string|
      if match = string.match(/^\|?([\w]+)\(([\w]+):([\w]+), /)
        datasources[match[1]] =  match[3]
      end
      datasources
    end
  end

  def parse_replication_roles(replication_roles_string)
    replication_roles_string.split(/\n/).inject({}) do |rep_roles, string|
      if match = string.match(/([\w]+)=([\w]+)/)
        rep_roles[match[2]] = match[1]
      end
      rep_roles
    end
  end

  def parse_latency(latency_string)
    latency_string.split(/, /).inject({}) do |latencies, string|
      if match = string.match(/([\w]+)=([\d]+\.[\d]*)s/)
        latencies[match[1]] = match[2].to_f
      end
      latencies
    end
  end

  def build_report
    datasources = {}

    status_string = %x(/opt/tungsten/cluster-home/bin/check_tungsten_online)
    replication_string = %x(/opt/tungsten/cluster-home/bin/get_replicator_roles)
    replication_roles = parse_replication_roles(replication_string)
    datasources_string = %x(echo "ls" | /opt/tungsten/tungsten-manager/bin/cctrl | grep progress)
    datasources = parse_datasources(datasources_string)
    latencies_string = %x(/opt/tungsten/cluster-home/bin/check_tungsten_latency -c 0)
    latencies = parse_latency(latencies_string)

    alert(:subject => "Could not parse online status", :body => status_string) if status_string.empty?
    alert(:subject => "Could not parse replication roles", :body => replication_string) if replication_roles.empty?
    alert(:subject => "Could not parse datasources", :body => datasources_string) if datasources.empty?
    alert(:subject => "Could not parse latencies", :body => latencies_string) if latencies.empty?

    if !status_string.empty? and !status_string.match(/OK/)
      alert("#{status_string}")
    end

    if memory(:replication_roles) and memory(:replication_roles) != replication_roles
      roles_string = replication_roles.inject("") do |output, datasource|
        output << "#{datasource.first} is now acting as #{datasource.last}"
      end
      alert(:subject => "Replication roles have changed.", :body => "#{roles_string}")
    end
    remember(:replication_roles => replication_roles)

    if option(:dr_only)
      datasources.each_pair do |source, status|
        alert(:subject => "#{source} datasource is ONLINE but should be OFFLINE.") if status == "ONLINE"
      end
    else
      datasources.each_pair do |source, status|
        alert(:subject => "#{source} datasource is OFFLINE but should be ONLINE.") if status == "OFFLINE"
      end
    end

    latencies.each_pair do |db, latency|
      report(:"#{db}_latency" => latency)
    end
  end
end

