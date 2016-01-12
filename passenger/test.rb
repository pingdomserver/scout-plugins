require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../passenger.rb', __FILE__)

class PassengerStatsTest < Test::Unit::TestCase
  def test_nginx_only
    stub_memory_stats FIXTURES[:nginx_only]
    stub_status FIXTURES[:status_pre_4]

    expected = [{
                    "passenger_process_inactive" => "2",
                    "passenger_process_active" => "0",
                    "passenger_process_current" => "2",
                    "passenger_max_pool_size" => "3",
                    "passenger_queue_depth" => "0"
                },
                {
                    "nginx_private_total" => 26.0,
                    "nginx_processes" => "5",
                    "nginx_vmsize_total" => 271.6,
                    "passenger_private_total" => 2251.4,
                    "passenger_processes" => "16",
                    "passenger_vmsize_total" => 4377.8
                }]

    actual = PassengerStats.new(nil, {}, {}).run()[:reports]

    assert_equal expected.first, actual.first
    assert_equal expected.last, actual.last
  end

  def test_apache_only
    stub_memory_stats FIXTURES[:apache_only]
    stub_status FIXTURES[:status_pre_4]

    expected = [{
                    "passenger_process_inactive" => "2",
                    "passenger_process_active" => "0",
                    "passenger_max_pool_size" => "3",
                    "passenger_process_current" => "2",
                    "passenger_queue_depth" => "0"

                },
                {
                    "apache_private_total"      => 7.6,
                    "apache_processes"          => "4",
                    "apache_vmsize_total"       => 1083.3,
                    "passenger_private_total"   => 214.8,
                    "passenger_vmsize_total"    => 636.3,
                    "nginx_processes"           => "0"

                } ]

    actual = PassengerStats.new(nil, {}, {}).run()[:reports]
    assert_equal expected.first, actual.first
    assert_equal expected.last, actual.last
  end

  def test_apache_only_passenger_4
    stub_memory_stats FIXTURES[:apache_only]
    stub_status FIXTURES[:status_4]

    expected = [{
                    "passenger_max_pool_size" => "6",
                    "passenger_process_current" => "5",
                    "passenger_queue_depth" => 5,
                  
                },
                {
                    "apache_private_total"      => 7.6,
                    "apache_processes"          => "4",
                    "apache_vmsize_total"       => 1083.3000000000002,
                    "passenger_private_total"   => 214.8,
                    "passenger_vmsize_total"    => 636.3,
                    "nginx_processes"           => "0"

                } ]

    actual = PassengerStats.new(nil, {}, {}).run()[:reports]
    assert_equal expected.first, actual.first
    assert_equal expected.last, actual.last
  end

  protected

  def stub_memory_stats(fixture)
    PassengerStats.any_instance.expects(:`).with("passenger-memory-stats 2>&1").returns(fixture).once
    `echo''>/dev/null` # total hack: the plugin checks $? (child process exit status) -- this sets $?
  end

  def stub_status(fixture)
    PassengerStats.any_instance.expects(:`).with("passenger-status 2>&1").returns(fixture).once
    `echo''>/dev/null` # total hack: the plugin checks $? (child process exit status) -- this sets $?
  end

  FIXTURES = YAML.load(<<-EOS)
    :status_pre_4: |
      max      = 3
      count    = 2
      active   = 0
      inactive = 2
      Waiting on global queue: 0
    :status_4: |
      Version : 4.0.41
      Date    : 2016-01-12 11:21:14 -0500
      Instance: 31713
      ----------- General information -----------
      Max pool size : 6
      Processes     : 5
      Requests in top-level queue : 0

      ----------- Application groups -----------
      /srv/scout/current#default:
        App root: /srv/scout/current
        Requests in queue: 2
        * PID: 20875   Sessions: 0       Processed: 0       Uptime: 1h 10m 1s
          CPU: 0%      Memory  : 161M    Last used: 1h 10m 1s

      scout_sinatra#default:
        App root: /srv/scout_sinatra/current
        Requests in queue: 3
        * PID: 29428   Sessions: 1       Processed: 3794335   Uptime: 260h 41m 9s
          CPU: 20%     Memory  : 85M     Last used: 0s ag

      scout#default:
        App root: /srv/scout/current
        Requests in queue: 0
        * PID: 20912   Sessions: 0       Processed: 2187    Uptime: 1h 10m 1s
          CPU: 6%      Memory  : 549M    Last used: 4s ago
    :nginx_only: |
      ------- Apache processes --------

      ### Processes: 0
      ### Total private dirty RSS: 0.00 MB


      ---------- Nginx processes ----------
      PID    PPID   VMSize   Private  Name
      -------------------------------------
      17881  1      49.8 MB  0.6 MB   nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
      18419  17881  54.3 MB  5.2 MB   nginx: worker process
      18516  17881  54.4 MB  5.2 MB   nginx: worker process
      18556  17881  58.3 MB  9.2 MB   nginx: worker process
      18557  17881  54.8 MB  5.8 MB   nginx: worker process
      ### Processes: 5
      ### Total private dirty RSS: 26.05 MB


      ----- Passenger processes ------
      PID    VMSize    Private   Name
      --------------------------------
      18381  160.9 MB  7.9 MB    PassengerNginxHelperServer /usr/lib/passenger ruby 3 4 0 40 0 3600 1 deploy 1000 1000 /tmp/passenger.17881
      18391  39.9 MB   8.4 MB    Passenger spawn server
      18632  308.8 MB  171.5 MB  Rails: /data/www/current
      18634  313.6 MB  176.0 MB  Rails: /data/www/current
      499    312.1 MB  173.5 MB  Rails: /data/www/current
      505    313.9 MB  175.3 MB  Rails: /data/www/current
      509    312.3 MB  173.5 MB  Rails: /data/www/current
      23732  296.4 MB  157.5 MB  Rails: /data/www/current
      23734  298.5 MB  159.9 MB  Rails: /data/www/current
      23736  305.5 MB  167.0 MB  Rails: /data/www/current
      23738  302.9 MB  164.0 MB  Rails: /data/www/current
      23740  302.6 MB  163.8 MB  Rails: /data/www/current
      23742  295.2 MB  156.2 MB  Rails: /data/www/current
      2982   230.0 MB  90.6 MB   Passenger ApplicationSpawner: /data/www/current
      3001   293.2 MB  154.2 MB  Rails: /data/www/current
      3191   292.0 MB  152.1 MB  Rails: /data/www/current
      ### Processes: 16
      ### Total private dirty RSS: 2251.22 MB

    :apache_only: |
      ---------- Apache processes ----------
      PID    PPID   VMSize    Private  Name
      --------------------------------------
      12715  23095  129.9 MB  0.6 MB   /usr/sbin/apache2 -k start
      12731  23095  411.8 MB  3.3 MB   /usr/sbin/apache2 -k start
      12759  23095  411.7 MB  3.2 MB   /usr/sbin/apache2 -k start
      23095  1      129.9 MB  0.5 MB   /usr/sbin/apache2 -k start
      ### Processes: 4
      ### Total private dirty RSS: 7.61 MB


      -------- Nginx processes --------

      ### Processes: 0
      ### Total private dirty RSS: 0.00 MB


      ----- Passenger processes -----
      PID    VMSize    Private  Name
      -------------------------------
      778    128.3 MB  54.1 MB  Rails: /var/www/apps/tempo/current
      6085   125.7 MB  50.0 MB  Passenger ApplicationSpawner: /var/www/apps/wifi/current
      6315   123.5 MB  45.4 MB  Passenger ApplicationSpawner: /var/www/apps/shapewiki/current
      12726  89.8 MB   1.5 MB   /usr/local/rvm/gems/ruby-1.9.1-p376/gems/passenger-2.2.9/ext/apache2/ApplicationPoolServerExecutable 0 /usr/local/rvm/gems/ruby-1.9.1-p376/gems/passenger-2.2.9/bin/passenger-spawn-server  /usr/local/bin/passenger_ruby  /tmp/passenger.23095
      12727  39.2 MB   11.6 MB  Passenger spawn server
      21162  129.8 MB  52.2 MB  Rails: /var/www/apps/wifi/current
      ### Processes: 6
      ### Total private dirty RSS: 214.95 MB
  EOS
end
