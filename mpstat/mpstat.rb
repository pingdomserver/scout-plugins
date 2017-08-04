class MPstat < Scout::Plugin

  OPTIONS=<<-EOS
  command:
    name: mpstat Command
    notes: The command used to display MP statistics
    default: mpstat
  interval:
    name: mpstat Interval
    notes: Report current usage as the average over this many seconds.
    default: 5
  EOS

  def build_report
    # Using the second reading- avg since previous check
    output = stat_output
    values,result=values(output),{}
    [:user, :nice, :sys, :iowait, :irq, :soft, :steal, :idle, :intrps].each{|k| result[k]=values[k]}
    report(result)
  rescue Exception => e
    error "Couldn't parse output. Make sure you have mpstat installed. #{e}"
  end

  private

  def stat_output()
    command = option('command') || 'mpstat'
    interval = option('interval') || 5
    stat_command = "#{command} #{interval} 2"
    `#{stat_command}`
  end

  def values(output)
    # Expected output format:
    # 04:38:34 PM  CPU   %user   %nice    %sys %iowait    %irq   %soft  %steal   %idle    intr/s
    # 04:38:34 PM  all    6.69    0.02    1.30    0.31    0.02    0.13    0.00   91.53    349.37
    # or:
    # 04:38:34 PM  CPU   %user   %nice    %sys %iowait    %irq   %soft  %steal   %idle    intr/s
    # 04:38:34 PM  all    6,69    0,02    1,30    0,31    0,02    0,13    0,00   91,53    349,37

    # take the format fields and replace "usr" with "user"
    format=output.split("\n").grep(/CPU/).last.gsub(/\//,'p').gsub(/(%|:)/,'')
      .gsub('usr', 'user').downcase.split
    #convert commas to dots when mpstat outputs data with commas
    output = output.gsub(',', '.')

    # take all the stat fields
    raw_stats=output.split("\n").grep(/[0-9]+\.[0-9]+$/).last.split

    stats={}
    format.each_with_index { |field,i| stats[ format[i].to_sym ]=raw_stats[i] }
    stats
  end

end
