require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../marathon_stats.rb', __FILE__)
require 'mocha/api'
include Mocha::API

class MarathonStatsTest < Test::Unit::TestCase

  def test_json_to_statsd
    test_json = { 'a' => 1 }
    prefix = "test_app"
    result = ["test_app.a:1|g"]

    @plugin = MarathonStats.new(nil, {}, {})
    test_result = @plugin.container_data_to_statsd(test_json, prefix)

    assert_equal result, test_result
  end

  def test_get_app_data
    url = "http://localhost/apps"
    id = "/alexia-stage"
    app_json='{
    "app": {
      "id": "/alexia-stage",
      "tasks": [
      {
        "ipAddresses": [
          {
            "ipAddress": "172.17.0.2",
            "protocol": "IPv4"
          }
        ],
        "stagedAt": "2017-06-23T16:39:11.338Z",
        "state": "TASK_RUNNING",
        "ports": [
          14218
        ],
        "startedAt": "2017-06-23T16:39:13.446Z",
        "version": "2017-06-23T16:38:12.190Z",
        "id": "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "appId": "/alexia-stage",
        "slaveId": "1ce5d6c3-1040-42c0-9a46-ccbaa42bc623-S0",
        "host": "paas-slave1.test.us-west-1.plexapp.info",
        "healthCheckResults": [
          {
            "alive": true,
            "consecutiveFailures": 0,
            "firstSuccess": "2017-06-23T16:39:22.608Z",
            "lastFailure": null,
            "lastSuccess": "2017-07-13T15:46:27.679Z",
            "lastFailureCause": null,
            "instanceId": "alexia-stage.marathon-7c32752c-5832-11e7-b955-02420aec263b"
          }
        ]
      }
    ]
    }
    }'

    FakeWeb.register_uri(:get, url+"/%s" % id, :body => app_json)
    @plugin = MarathonStats.new(nil, {}, {:marathon_url => url})
    app_data = @plugin.get_app_data(id)
    assert_equal id, app_data["id"]
    assert_equal "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b", app_data["tasks"][0]["id"]
  end

  def test_get_containers
    test_json = '[
      {
        "container_id": "3963823d-da89-4dfd-80c5-4d2bbd9f3054",
        "executor_id": "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "executor_name": "Command Executor (Task: alexia-stage.7c32752c-5832-11e7-b955-02420aec263b) (Command: sh -c \'npm run stage\')",
        "framework_id": "462eeb66-d4c3-40b5-87aa-6255216f0dca-0001",
        "source": "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "statistics": {
          "cpus_limit": 0.6,
          "cpus_system_time_secs": 61989.46,
          "cpus_user_time_secs": 65629.34,
          "mem_limit_bytes": 570425344,
          "mem_rss_bytes": 147062784,
          "timestamp": 1499969552.69007
        },
        "status": {
          "container_id": {
            "value": "3963823d-da89-4dfd-80c5-4d2bbd9f3054"
          }
        }
      }
    ]'
    test_hash = [
      {
        "container_id" => "3963823d-da89-4dfd-80c5-4d2bbd9f3054",
        "executor_id" => "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "executor_name" => "Command Executor (Task: alexia-stage.7c32752c-5832-11e7-b955-02420aec263b) (Command: sh -c \'npm run stage\')",
        "framework_id" => "462eeb66-d4c3-40b5-87aa-6255216f0dca-0001",
        "source" => "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "statistics" => {
          "cpus_limit" => 0.6,
          "cpus_system_time_secs" => 61989.46,
          "cpus_user_time_secs" => 65629.34,
          "mem_limit_bytes" => 570425344,
          "mem_rss_bytes" => 147062784,
          "timestamp" => 1499969552.69007
        },
        "status" => {
          "container_id" => {
            "value" => "3963823d-da89-4dfd-80c5-4d2bbd9f3054"
          }
        }
      }
    ]
    url = "http://localhost/containers"
    FakeWeb.register_uri(:get, url, :body => test_json)

    @plugin = MarathonStats.new(nil, {}, {:mesos_containers_url => url})

    containers = @plugin.get_containers()

    # assert_not_nil containers
    # assert_equal false, containers.empty?
    # assert_equal "3963823d-da89-4dfd-80c5-4d2bbd9f3054", containers[0]["container_id"]
    assert_equal test_hash, containers
  end

  def test_build_report
    containers_json = '[
      {
        "container_id": "3963823d-da89-4dfd-80c5-4d2bbd9f3054",
        "executor_id": "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "executor_name": "Command Executor (Task: alexia-stage.7c32752c-5832-11e7-b955-02420aec263b) (Command: sh -c \'npm run stage\')",
        "framework_id": "462eeb66-d4c3-40b5-87aa-6255216f0dca-0001",
        "source": "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
        "statistics": {
          "cpus_limit": 0.6,
          "cpus_system_time_secs": 61989.46,
          "cpus_user_time_secs": 65629.34,
          "mem_limit_bytes": 570425344,
          "mem_rss_bytes": 147062784,
          "timestamp": 1499969552.69007
        },
        "status": {
          "container_id": {
            "value": "3963823d-da89-4dfd-80c5-4d2bbd9f3054"
          }
        }
      }
    ]'

    apps_json = '{
      "apps": [
        {
          "id": "/alexia-stage",
          "cmd": "npm run stage",
          "args": null,
          "user": null,
          "env": {
            "SERVICE_8000_NAME": "alexa-stage",
            "SERVICE_8000_TAGS": "alexa-stage,nginx,haproxy,haproxy_weight=100,haproxy_httpchk=GET /health",
            "NODE_ENV": "staging",
            "PORT": "8000",
            "SERVICE_8000_CHECK_HTTP": "/health"
          },
          "instances": 1,
          "cpus": 0.5,
          "mem": 512,
          "disk": 0,
          "gpus": 0,
          "executor": "",
          "constraints": [],
          "uris": [],
          "fetch": [],
          "storeUrls": [],
          "backoffSeconds": 1,
          "backoffFactor": 1.15,
          "maxLaunchDelaySeconds": 3600,
          "container": {
            "type": "DOCKER",
            "volumes": [],
            "docker": {
              "image": "plexinc/alexa-plex:develop-59f1212",
              "network": "BRIDGE",
              "portMappings": [
                {
                  "containerPort": 8000,
                  "hostPort": 0,
                  "servicePort": 10000,
                  "protocol": "tcp",
                  "labels": {}
                }
              ],
              "privileged": false,
              "parameters": [],
              "forcePullImage": true
            }
          },
          "healthChecks": [
            {
              "gracePeriodSeconds": 5,
              "intervalSeconds": 5,
              "timeoutSeconds": 10,
              "maxConsecutiveFailures": 2,
              "portIndex": 0,
              "path": "/health",
              "protocol": "HTTP",
              "ignoreHttp1xx": false
            }
          ],
          "readinessChecks": [],
          "dependencies": [],
          "upgradeStrategy": {
            "minimumHealthCapacity": 1,
            "maximumOverCapacity": 1
          },
          "labels": {},
          "ipAddress": null,
          "version": "2017-06-23T16:39:35.297Z",
          "residency": null,
          "secrets": {},
          "taskKillGracePeriodSeconds": null,
          "unreachableStrategy": {
            "inactiveAfterSeconds": 300,
            "expungeAfterSeconds": 600
          },
          "killSelection": "YOUNGEST_FIRST",
          "ports": [
            10000
          ],
          "portDefinitions": [
            {
              "port": 10000,
              "protocol": "tcp",
              "name": "default",
              "labels": {}
            }
          ],
          "requirePorts": false,
          "versionInfo": {
            "lastScalingAt": "2017-06-23T16:39:35.297Z",
            "lastConfigChangeAt": "2017-06-23T16:38:12.190Z"
          },
          "tasksStaged": 0,
          "tasksRunning": 1,
          "tasksHealthy": 1,
          "tasksUnhealthy": 0,
          "deployments": []
        }
      ]
    }'

    app_json = '{
      "app": {
        "id": "/alexia-stage",
        "cmd": "npm run stage",
        "args": null,
        "user": null,
        "env": {
          "SERVICE_8000_NAME": "alexa-stage",
          "SERVICE_8000_TAGS": "alexa-stage,nginx,haproxy,haproxy_weight=100,haproxy_httpchk=GET /health",
          "NODE_ENV": "staging",
          "PORT": "8000",
          "SERVICE_8000_CHECK_HTTP": "/health"
        },
        "instances": 1,
        "cpus": 0.5,
        "mem": 512,
        "disk": 0,
        "gpus": 0,
        "executor": "",
        "constraints": [],
        "uris": [],
        "fetch": [],
        "storeUrls": [],
        "backoffSeconds": 1,
        "backoffFactor": 1.15,
        "maxLaunchDelaySeconds": 3600,
        "container": {
          "type": "DOCKER",
          "volumes": [],
          "docker": {
            "image": "plexinc/alexa-plex:develop-59f1212",
            "network": "BRIDGE",
            "portMappings": [
              {
                "containerPort": 8000,
                "hostPort": 0,
                "servicePort": 10000,
                "protocol": "tcp",
                "labels": {}
              }
            ],
            "privileged": false,
            "parameters": [],
            "forcePullImage": true
          }
        },
        "healthChecks": [
          {
            "gracePeriodSeconds": 5,
            "intervalSeconds": 5,
            "timeoutSeconds": 10,
            "maxConsecutiveFailures": 2,
            "portIndex": 0,
            "path": "/health",
            "protocol": "HTTP",
            "ignoreHttp1xx": false
          }
        ],
        "readinessChecks": [],
        "dependencies": [],
        "upgradeStrategy": {
          "minimumHealthCapacity": 1,
          "maximumOverCapacity": 1
        },
        "labels": {},
        "ipAddress": null,
        "version": "2017-06-23T16:39:35.297Z",
        "residency": null,
        "secrets": {},
        "taskKillGracePeriodSeconds": null,
        "unreachableStrategy": {
          "inactiveAfterSeconds": 300,
          "expungeAfterSeconds": 600
        },
        "killSelection": "YOUNGEST_FIRST",
        "ports": [
          10000
        ],
        "portDefinitions": [
          {
            "port": 10000,
            "protocol": "tcp",
            "name": "default",
            "labels": {}
          }
        ],
        "requirePorts": false,
        "versionInfo": {
          "lastScalingAt": "2017-06-23T16:39:35.297Z",
          "lastConfigChangeAt": "2017-06-23T16:38:12.190Z"
        },
        "tasksStaged": 0,
        "tasksRunning": 1,
        "tasksHealthy": 1,
        "tasksUnhealthy": 0,
        "deployments": [],
        "tasks": [
          {
            "ipAddresses": [
              {
                "ipAddress": "172.17.0.2",
                "protocol": "IPv4"
              }
            ],
            "stagedAt": "2017-06-23T16:39:11.338Z",
            "state": "TASK_RUNNING",
            "ports": [
              14218
            ],
            "startedAt": "2017-06-23T16:39:13.446Z",
            "version": "2017-06-23T16:38:12.190Z",
            "id": "alexia-stage.7c32752c-5832-11e7-b955-02420aec263b",
            "appId": "/alexia-stage",
            "slaveId": "1ce5d6c3-1040-42c0-9a46-ccbaa42bc623-S0",
            "host": "paas-slave1.test.us-west-1.plexapp.info",
            "healthCheckResults": [
              {
                "alive": true,
                "consecutiveFailures": 0,
                "firstSuccess": "2017-06-23T16:39:22.608Z",
                "lastFailure": null,
                "lastSuccess": "2017-07-13T15:46:27.679Z",
                "lastFailureCause": null,
                "instanceId": "alexia-stage.marathon-7c32752c-5832-11e7-b955-02420aec263b"
              }
            ]
          }
        ],
        "lastTaskFailure": {
          "appId": "/alexia-stage",
          "host": "paas-slave2.test.eu-west-1.plexapp.info",
          "message": "Failed to launch container: Failed to run \'docker -H unix:///var/run/docker.sock inspect mesos-1ce5d6c3-1040-42c0-9a46-ccbaa42bc623-S2.fac6b66c-97a6-48e8-92fa-2729acd24dba\': exited with status 1; stderr=\'Error: No such object: mesos-1ce5d6c3-1040-42c0-9a46-ccbaa42bc623-S2.fac6b66c-97a6-48e8-92fa-2729acd24dba\n\'",
          "state": "TASK_FAILED",
          "taskId": "alexia-stage.58fa311b-5832-11e7-b955-02420aec263b",
          "timestamp": "2017-06-23T16:39:10.316Z",
          "version": "2017-06-23T16:38:12.190Z",
          "slaveId": "1ce5d6c3-1040-42c0-9a46-ccbaa42bc623-S2"
        }
      }
    }'

    containers_url = "http://localhost/containers"
    apps_url = "http://localhost/apps"
    app_url = "http://localhost/apps//alexia-stage"
    scout_address = "localhost"
    scout_port = 8125
    FakeWeb.register_uri(:get, containers_url, :body => containers_json)
    FakeWeb.register_uri(:get, apps_url, :body => apps_json)
    FakeWeb.register_uri(:get, app_url, :body => app_json)
    udpsocket = mock()
    udpsocket.expects(:send).times(6)

    @plugin = MarathonStats.new(nil, {}, {:mesos_containers_url => containers_url, :marathon_url => apps_url, :scoutd_address => scout_address, :scoutd_port => scout_port})
    @plugin.instance_variable_set("@socket", udpsocket)
    # @plugin.expects(:send_statsd).times(6) # number of statistics for container

    @plugin.run()
  end

end
