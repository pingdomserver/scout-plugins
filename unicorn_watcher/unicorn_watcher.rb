require 'scout'

class UnicornWatcher < Scout::Plugin

  attr_accessor :pid, :running

  OPTIONS=<<-EOS
    directory:
      default: /var/run/engineyard/unicorn/g5searchmarketing/unicorn.pid
      name: Location of pid file
      notes: Location of the unicorn.pid file, this will depend on how your unicorn is configured
    process_name:
      default: unicorn_rails master
      name: Name of unicorn master process_name
      notes: Typically unicorn master or unicorn_master. Do a ps aux|grep unicorn to see what yours is called.
  EOS

  def build_report
    self.running = false
    if File.exist?(option(:directory))
      self.pid = File.read(option(:directory)).to_i
      self.running = self.is_running?
    end
    report(:unicorn_master_count => self.get_count)
    trigger_alert
  end

  def is_running?
    return false unless pid
    begin
      output = `ps p #{self.pid}`
    rescue
      return false
    end
    output.include?(self.pid.to_s) && output.include?(option(:process_name))
  end

  def trigger_alert
    unless self.running
      alert('Unicorn master not running','Unicorn master not detected on this slice.')
    end
  end

  def get_count
    self.running ? 1 : 0
  end

end