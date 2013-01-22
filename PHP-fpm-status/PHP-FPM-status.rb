class PHPFpmStatus < Scout::Plugin
  needs 'open-uri', 'json'

  OPTIONS=<<-EOS
  url:
    name: FPM Status Url
    default: "http://localhost/status?json"
  EOS

  def build_report
    url = option(:url) || 'http://localhost/status?json'
    begin
        open(url) do |p|
          content = p.read
          stats = JSON.parse(content)
          report({
                :is_up => 1,
                :start_since          => stats["start since"].to_i,
                :idle_processes       => stats["idle processes"].to_i,
                :active_processes     => stats["active processes"].to_i,
                :total_processes      => stats["total processes"].to_i,
                :accepted_conn        => stats["accepted conn"].to_i,
                :listen_queue         => stats["listen queue"].to_i,
                :listen_queue_len     => stats["listen queue len"].to_i,
                :max_active_processes => stats["max active processes"].to_i,
                :max_children_reached => stats["max children reached"].to_i
                })
        end
    rescue StandardError => trouble
      report({
            :is_up => 0,
            :message => "#{trouble} #{trouble.backtrace}"
            })
    end     
  end
end
