# Reports number of matched occurrences in log content since last check.
# Handles rolling log files where rolling is handled by renaming the log file
# (e.g. glassfish logging).
#
# Derived from Yaroslav Lazor's Log Watcher plugin:
# https://raw.github.com/highgroove/scout-plugins/master/log_watcher/log_watcher.rb
#
# Steve Ims (steve_ims@yahoo.com)
class RollingLogWatcher < Scout::Plugin
  needs 'find'
  needs 'tempfile'

  OPTIONS = <<-EOS
  log_path:
    name: Log path
    notes: Full path to the the log file
  grep_args:
    default: "Exception"
    name: Grep args
    notes: Arguments passed to grep invocation (grep -c {grep_args} file)
  EOS
  
  def init
    @log_file_path = option('log_path').to_s.strip
    if @log_file_path.empty?
      return error('log_path cannot be empty')
    end
    
    @grep_args = option('grep_args').to_s.strip
    if @grep_args.empty?
      return error('grep_args cannot be empty')
    end

    # Isolate new log content for scanning
    @tmpfile = Tempfile.new('scannable_content').path

    nil
  end
  
  # Scout method
  def build_report
    return if init()

    last_inode = memory(:last_inode)

    # Handle case where log file rolled, replacement not yet created.
    current_inode = `ls -il #{@log_file_path}`.split(' ')[0].to_i
    if !$?.success?
      current_inode = nil
    end

    # Don't scan first time.
    # Set current length as starting point for next check.
    # Avoids repeat parsing of existing content
    # (e.g. plugin updates drop state from previous invocations).
    if last_inode
      last_bytes = memory(:last_bytes) || -1

      # Process remainder of last file.
      f = get_file_by_inode(last_inode)
      current_length = pend_scannable_content(f, last_bytes+1)
      f.close

      remember(:last_bytes => current_length)

      # Process new log file, if found.
      if current_inode && last_inode != current_inode
        f = get_file_by_inode(current_inode)
        current_length = pend_scannable_content(f, 0)
        f.close

        remember(:last_bytes => current_length)
      end

      count = `grep -c #{@grep_args} #{@tmpfile}`.strip.to_i
      report(:occurrences => count)
    end

    if current_inode
      remember(:last_inode => current_inode)
    elsif last_inode
      remember(:last_inode => last_inode)
    end
  end

  # Use fd to safely track content, even during rollover.
  def get_file_by_inode(inode)
    d = File.dirname(@log_file_path)
    Find.find( d ) do |f|
      if !defined? matched_file && File.file?( f )
        candidate = File.open( f )
        if candidate.stat.ino == inode
          return candidate
        else
          candidate.close
        end
      end
    end

    raise "Cannot find log file by inode: directory #{d}; inode #{inode}."
  end

  # Copy new content into tmpfile with limited-sized chunks.
  def pend_scannable_content(f, from)
    f.seek( from )
    current_length = f.stat.size
    read_length = current_length - from + 1
    if read_length > 0
      open( @tmpfile, 'a' ) do |out|
        max_bytes = 4096
        (1..( read_length/max_bytes )).each do
          out.write( f.read( max_bytes ))
        end
        out.write( f.read( read_length%max_bytes ))
      end
    end

    return current_length
  end
end
