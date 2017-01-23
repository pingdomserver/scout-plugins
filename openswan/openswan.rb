class Openswan < Scout::Plugin

  OPTIONS = <<-EOS
  use_sudo:
    default: 0
    notes: 1=use sudo. In order to use the sudo option, your scout user will need to have passwordless sudo privileges.
  EOS

  def build_report
    sudo_cmd = option('use_sudo').to_i == 1 ? 'sudo ' : ''

    status = `#{sudo_cmd}service ipsec status`
    match = status.match(/(\d+) tunnels up/)

    res = match ? match[1].to_i : 0

    report(num_tunnels_up: res)
  end
end
