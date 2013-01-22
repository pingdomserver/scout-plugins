class NTPStat < Scout::Plugin
  def build_report
    report('NSync' => system('ntpstat') ? 1 : 0)
  end
end