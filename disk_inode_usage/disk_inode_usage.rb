class DiskInodeUsage < Scout::Plugin
  # Heavily borrowed from Scout's DiskUsage plugin

  OPTIONS=<<-EOS
  command:
    name: df Command
    notes: The command used to display free inodes
    default: df -i
  EOS

  DF_RE = /\A\s*(\S.*?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*\z/

  def parse_file_systems(io, &line_handler)
    line_handler ||= lambda { |row| pp row }
    headers = nil
    row = ""
    io.each_line do |line|
      if headers.nil? and line =~ /\AFilesystem/
        headers = line.split(" ", 6)
      else
        row << line
        if row =~ DF_RE
          fields = $~.captures
          line_handler[headers ? Hash[*headers.zip(fields).flatten] : fields]
          row = ""
        end
      end
    end
  end

  def build_report
    ENV['lang'] = 'C' # forcing English for parsing
    df_command   = option('command') || 'df -i'
    df_output    = `#{df_command}`
    
    df_lines = []
    parse_file_systems(df_output) { |row| df_lines << row }
    
    # else just use the first line
    df_line ||= df_lines.first
    
    # remove 'filesystem' and 'mounted on' if present - these don't change. 
    df_line.reject! { |name,value| ['filesystem','mounted on'].include?(name.downcase.gsub(/\n/,'')) }  
    
    # will be passed at the end to report to Scout
    report_data = Hash.new
    
    df_line.each do |name, value|
      report_data[name.downcase.strip.to_sym] = value
    end
    report(report_data)
  end
end
