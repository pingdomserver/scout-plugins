class Jstat < Scout::Plugin
  OPTIONS=<<-EOS
    statOption:
      default: gc
      notes: Which of the stat options class, compiler, gc... that are returned by jstat -options
    columns:
      name: Columns
      notes: Which columns to track. These are case-sensitive based off the jstat headers
    pidFile:
      name: PID File
      notes: The file containing the pid of the jvm to monitor    
  EOS
  
  def build_report
    pidFile = option(:pidFile)
    raise "PID File \"#{pidFile}\" does not exist" unless (pidFile && File.exist?(pidFile))
    jvm_pid = `cat #{pidFile}`
    (headers, output) = `jstat -#{option(:statOption)} #{jvm_pid}`.split("\n")
    metrics = Hash[*headers.split.map(&:to_sym).zip(output.split).flatten]
    if option(:columns)
      columns = option(:columns).split(/[,\s]+/).map(&:to_sym)
      puts "Columns: #{columns.join('|')}"
      metrics = Hash[metrics.select{|key, value| columns.include?(key)}]
    end
    report(metrics)

  end
end