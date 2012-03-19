# Created by Jean-Luc Geering (http://github.com/jlgeering) at UFirst Group (http://github.com/ufirstgroup http://www.ufirstgroup.com/)
class MagentoMonitoring < Scout::Plugin

  OPTIONS=<<-EOS
    directory:
      name: Magento base directory
    fs_cache_directory:
      name: FS cache directory
      notes: absolute, or relative to Magento base directory
      default: "var/cache/"
  EOS

  def build_report
    report = {}

    magento_dir     = option(:directory)
    magento_dir     = magento_dir + '/' unless magento_dir =~ /\/$/

    fs_cache_dir = option(:fs_cache_directory)
    fs_cache_dir = magento_dir + fs_cache_dir unless fs_cache_dir =~ /^\//

    fs_cache_size    = `du -s #{fs_cache_dir}`
    # http://magebase.com/magento-tutorials/improving-the-file-cache-backend/
    fs_cache_entries = `find #{fs_cache_dir} -type f | grep internal-metadatas | wc -l`

    report['fs_cache_size']    = fs_cache_size.split[0].to_i
    report['fs_cache_entries'] = fs_cache_entries.chomp.to_i

    report(report) if report.values.compact.any?
  end
end