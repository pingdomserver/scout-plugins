#
# A Scout plugin to collect CPU usage from a system
#
# Created by Eric Lindvall <eric@sevenscale.com>
#

class CpuUsage < Scout::Plugin
  needs "time"
  def build_report
    stats = CpuStats.fetch

    if previous = memory(:cpu_stats)
      previous_stats = CpuStats.from_hash(previous)

      report(stats.diff(previous_stats))
    end

    remember(:cpu_stats => stats.to_h)
  rescue Exception => e
    error("Error running plugin: #{e.class}", e.message)
  end

  class CpuStats
    attr_accessor :user, :system, :idle, :iowait, :interrupts, :procs_running, :procs_blocked, :time, :steal, :guest, :guest_nice

    def self.fetch
      data      = %x(cat /proc/stat).split(/\n/).collect { |line| line.split }
      cpu_stats = CpuStats.new

      if cpu = data.detect { |line| line[0] == 'cpu' }
        cpu_stats.user, nice, cpu_stats.system, cpu_stats.idle, cpu_stats.iowait,
          hardirq, softirq, cpu_stats.steal, cpu_stats.guest, guest_nice = *cpu[1..-1].collect { |c| c.to_i }

        cpu_stats.user   += nice
        cpu_stats.system += hardirq + softirq

        if cpu_stats.guest && guest_nice
          cpu_stats.guest += guest_nice
        end
      end

      if interrupts = data.detect { |line| line[0] == 'intr' }
        cpu_stats.interrupts, _ = *interrupts[1..-1].collect { |c| c.to_i }
      end

      if procs_running = data.detect { |line| line[0] == 'procs_running' }
        cpu_stats.procs_running, _ = *procs_running[1..-1].collect { |c| c.to_i }
      end

      if procs_blocked = data.detect { |line| line[0] == 'procs_blocked' }
        cpu_stats.procs_blocked, _ = *procs_blocked[1..-1].collect { |c| c.to_i }
      end

      cpu_stats
    end

    def self.from_hash(h)
      cpu_stats= CpuStats.new
      hash = {}
      h.each { |k,v| hash[k.to_sym] = v }

      if time = hash.delete(:time)
        cpu_stats.time = Time.parse(time) rescue time
      end

      hash.each do |k, v|
        cpu_stats.send("#{k}=", v) if cpu_stats.respond_to?("#{k}=")
      end
      cpu_stats
    end

    def initialize
      self.time = Time.now
    end

    def diff(other)
      diff_user   = user - other.user
      diff_system = system - other.system
      diff_idle   = idle - other.idle
      diff_iowait = iowait - other.iowait

      div = diff_user + diff_system + diff_idle + diff_iowait

      if steal && other.steal && steal > 0
        diff_steal = steal - other.steal
        div += diff_steal
      end

      if guest && other.guest && guest > 0
        diff_guest = guest - other.guest
        div += diff_guest
      end

      divo2 = div / 2

      results = {
        :user          => (100.0 * diff_user + divo2) / div,
        :system        => (100.0 * diff_system + divo2) / div,
        :idle          => (100.0 * diff_idle + divo2) / div,
        :iowait        => (100.0 * diff_iowait + divo2) / div,
        :procs_running => self.procs_running,
        :procs_blocked => self.procs_blocked
      }

      if diff_steal && steal > 0
        results[:steal] = (100.0 * diff_steal + divo2) / div
      end

      if diff_guest && guest > 0
        results[:guest] = (100.0 * diff_guest + divo2) / div
      end

      if self.time && other.time
        diff_in_seconds = self.time.to_f - other.time.to_f

        results[:interrupts] = (self.interrupts.to_f - other.interrupts.to_f) / diff_in_seconds
      end

      results
    end

    def to_h
      {
        :user => user, :system => system, :idle => idle, :iowait => iowait,
        :interrupts => interrupts, :procs_running => procs_running,
        :procs_blocked => procs_blocked, :time => Time.now.to_s,
        :steal => steal, :guest => guest
      }
    end
  end
end
