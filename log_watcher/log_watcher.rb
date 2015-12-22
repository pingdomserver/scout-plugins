class LogWatcher < Scout::Plugin
  OPTIONS = <<-EOS
  log_path:
    name: Log path
    notes: Full path to the the log file
  term:
    default: "[Ee]rror"
    name: Term
    notes: Returns the number of matches for this term. Use Linux Regex formatting.
  grep_options:
    name: Grep Options
    notes: Provide any options to pass to grep when running. For example, to count non-matching lines, enter 'v'. Use the abbreviated format ('v' and not 'invert-match').
  send_error_if_no_log:
    attributes: advanced
    default: 1
    notes: 1=yes
  use_sudo:
    attributes: advanced
    default: 0
    notes: 1=use sudo. In order to use the sudo option, your scout user will need to have passwordless sudo privileges.
  EOS
  
  def init
    if option('use_sudo').to_i == 1
      @sudo_cmd = "sudo "
    else
      @sudo_cmd = ""
    end

    @log_file_path = option("log_path").to_s.strip
    if @log_file_path.empty?
      return error( "Please provide a path to the log file." )
    end
    
    `#{@sudo_cmd}test -e #{@log_file_path}`
    
    unless $?.success?
      error("Could not find the log file", "The log file could not be found at: #{@log_file_path}. Please ensure the full path is correct and your user has permissions to access the log file.") if option("send_error_if_no_log") == "1"
      return
    end

    @term = option("term").to_s.strip
    if @term.empty?
      return error( "The term cannot be empty" )
    end
    nil
  end
  
  def build_report
    return if init()
    
    last_bytes = memory(:last_bytes) || 0
    output = `#{@sudo_cmd}wc -c #{@log_file_path}  2>&1`

    unless $?.success?
      error("Unable to access the log file", "The log file at [#{@log_file_path}] could not be accessed. Please ensure file permissions are correct. Error:\n\n#{output}")
      return
    end

    current_length = output.split(' ')[0].to_i

    count = 0
    elapsed_seconds = 0
    # don't run it the first time
    if (last_bytes > 0 )
      read_length = current_length - last_bytes
      # Check to see if this file was rotated. This occurs when the +current_length+ is less than 
      # the +last_run+. Don't return a count if this occured.
      if read_length >= 0
        # finds new content from +last_bytes+ to the end of the file, then just extracts from the recorded 
        # +read_length+. This ignores new lines that are added after finding the +current_length+. Those lines 
        # will be read on the next run.
        count = `#{@sudo_cmd}tail -c +#{last_bytes+1} #{@log_file_path} | head -c #{read_length} | grep "#{@term}" -#{option(:grep_options).to_s.gsub('-','')}c`.strip.to_f
        # convert to a rate / min
        elapsed_seconds = Time.now - @last_run
        count = count / (elapsed_seconds/60)
      else
        count = nil
      end
    end
    report(:occurances => count) if count and elapsed_seconds >= 1
    remember(:last_bytes, current_length)
  end
end
