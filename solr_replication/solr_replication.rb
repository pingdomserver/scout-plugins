class SolrReplication < Scout::Plugin
  needs 'open-uri'

  OPTIONS=<<-EOS
  master_ip:
    default: 192.168.0.1
  master_port:
    default: 8983
  slave_ip:
    default: localhost
  slave_port:
    default: 8765
  replication_path:
    default: /solr/admin/replication/index.jsp
  EOS

  def build_report
    master_position = position_for(master_host)
    slave_position = position_for(slave_host)
    if master_position and slave_position
      report 'delay' => master_position.to_i - slave_position.to_i
    else
      error "Incorrect values found master:#{master_position.inspect} slave:#{slave_position.inspect}"
    end
  end

  private

  def position_for(host)
    generation_regex = /Generation: (\d+)/
    open(host).read.match(generation_regex)[1]
  rescue => e
    error "Error connecting to #{host}: #{e.message}"
    nil
  end

  def master_host
    "http://#{option(:master_ip)}:#{option(:master_port)}#{option("replication_path")}"
  end

  def slave_host
    "http://#{option(:slave_ip)}:#{option(:slave_port)}#{option("replication_path")}"
  end
end
