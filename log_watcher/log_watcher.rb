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
    
    @term = option("term").to_s.strip
    if @term.empty?
      return error( "The term cannot be empty" )
    end
    nil
  end
  
  def build_report
    return if init()
    
    last_bytes = memory(:last_bytes) || 0
    # inode 0 does not exist. So this is a "no-file" marker for both last_inode and current_inode
    last_inode = memory(:last_inode) || 0
    current_inode = `#{@sudo_cmd}ls -i #{@log_file_path}`.split(' ')[0].to_i
    rotated_path = ""

    # see if we had a file rotation (with straight mv)
    if current_inode != last_inode && last_inode != 0
      # we look for a rotated file path in the same directory tree as the original file
      rotated_path = `find #{File::dirname(@log_file_path)} -inum #{last_inode}`.strip
      $stderr.puts rotated_path

      # if the file's gone, we just start fresh. Otherwise we continue scanning the old file this one last time
      if rotated_path.empty?
        last_bytes = 0
      else
        @log_file_path = rotated_path unless rotated_path.empty?
      end
    end

    `#{@sudo_cmd}test -e #{@log_file_path}`

    unless $?.success?
      if option("send_error_if_no_log") == "0"
        last_bytes = 0
      else
        error("Could not find the log file", "The log file could not be found at: #{@log_file_path}. Please ensure the full path is correct and your user has permissions to access the log file.")
        return
      end
    end

    current_length = `#{@sudo_cmd}wc -c #{@log_file_path}`.split(' ')[0].to_i
    # don't run unless we have at least a 1 second sample
    if @last_run && Time.now - @last_run >= 1
      # we don't have to handle cases where the file has been rotated... those would have been handled above. We should always
      # have our current_length at least equal to where we're at. If not, we start fresh and warn.
      if current_length < last_bytes
        error("There has been an internal error in logic. Scanning from the beginning of log file #{@log_file_path}")
        last_bytes = 0
      end
      read_length = current_length - last_bytes

      # finds new content from +last_bytes+ to the end of the file, then just extracts from the recorded 
      # +read_length+. This ignores new lines that are added after finding the +current_length+. Those lines 
      # will be read on the next run.
      count = `#{@sudo_cmd}tail -c +#{last_bytes+1} #{@log_file_path} | head -c #{read_length} | grep "#{@term}" -#{option(:grep_options).to_s.gsub('-','')}c`.strip.to_f
      # convert to a rate / min
      elapsed_seconds = Time.now - @last_run
      count = count / (elapsed_seconds/60)
			report(:occurances => count)
    end

    # if we scanned our rotated file, we want to start fresh with our new file, so we remember zero for last_bytes.
    if rotated_path.empty?
      remember(:last_bytes, current_length)
    else
      remember(:last_bytes, 0)
    end
    remember(:last_inode, current_inode)
  end
end
