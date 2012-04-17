class Iostat < Scout::Plugin

  OPTIONS=<<-EOS
  device:
    name: Device
    notes: The device to check, eg 'sda1'. If not specified, uses the device mounted at '/'
  EOS

  def build_report
    @default_device_used = false
    # determine the device, either from the passed option or by parsing `mount`
    device = option('device') || default_device
    stats = iostat(device)
    error("Device not found: #{device} -- check your plugin settings.",
          "FYI, mount returns:\n#{`mount`}") and return if !stats

    counter(:rps,   stats['rio'],        :per => :second)
    counter(:wps,   stats['wio'],        :per => :second)
    counter(:rkbps, stats['rsect'] / 2,  :per => :second)
    counter(:wkbps, stats['wsect'] / 2,  :per => :second)
    counter(:util,  stats['use'] / 10.0, :per => :second)
    # Not 100% sure that average queue length is present on all distros.
    if stats['aveq']
      counter(:aveq,  stats['aveq'], :per => :second)
    end

    if old = memory("#{device}_stats")
      ios = (stats['rio'] - old['rio']) + (stats['wio']  - old['wio'])

      if ios > 0
        await = ((stats['ruse'] - old['ruse']) + (stats['wuse'] - old['wuse'])) / ios.to_f

        report(:await => await)
      end
    end

    remember("#{device}_stats" => stats)
  end
  
  private
  COLUMNS = %w(major minor name rio rmerge rsect ruse wio wmerge wsect wuse running use aveq)
  
  # Returns the device mounted at "/"
  def default_device
    @default_device_used = true
    `mount`.split("\n").grep(/ \/ /)[0].split[0]
  end

  def iostat(dev)
    # if a LVM is used, `mount` output doesn't map to `/diskstats`. In this case, use dm-0 as the default device.
    lvm = nil
    retried = false
    begin
      %x(cat /proc/diskstats).split(/\n/).each do |line|
        entry = Hash[*COLUMNS.zip(line.strip.split(/\s+/).collect { |v| Integer(v) rescue v }).flatten]
        return entry if dev == entry['name']
        lvm = entry if (@default_device_used and 'dm-0'.include?(entry['name']))
      end
    rescue Errno::EPIPE
      if retried
        raise
      else
        retried = true
        retry
      end
    end
    return lvm
  end
end
