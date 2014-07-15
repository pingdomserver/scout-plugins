$VERBOSE=false
class ForkRate < Scout::Plugin
  def build_report
    vmstat      = `which vmstat`.strip
    forks       = `#{vmstat} -f|awk '{print $1}'`.to_i
    counter(:forks,forks, :per => :minute)
  end
end

