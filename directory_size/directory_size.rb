class DirectorySize < Scout::Plugin
	OPTIONS=<<-EOS
  directory:
    name: df Command
    notes: The full path to the directory you wish to monitor disk usage for.
  EOS

  def build_report
  	directory = option(:directory)
  	if directory.to_s.strip == ''
  		return error("The full path to a directory is required","Please provide a full path to the directory you wish to monitor in the plugin settings.")
  	end
  	output = `du -s #{directory} 2>&1`
  	if !$?.success?
  		return error("Error fetching directory size for [#{directory}]","Output:\n\n#{output}")
  	end
  	size_in_bytes = output.split("\n").last.split("\t").first.to_i
  	report(size: size_in_bytes/1024.0) # MB
  end
end