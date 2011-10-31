require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../couchdb_overall_monitoring.rb', __FILE__)

require 'open-uri'
class CouchDBOverallMonitoringTest < Test::Unit::TestCase
  def setup
    setup_urls
  end
  
  def teardown
    FakeWeb.clean_registry    
  end
  
  def test_initial_run
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert_equal res[:memory]["_counter_database_reads"][:value], 100
    assert_equal res[:memory]["_counter_database_writes"][:value], 1000    
  end
  
  def test_no_httpd_group
    uri="http://127.0.0.1:5984/_stats"
    FakeWeb.register_uri(:get, uri, :body => FIXTURES[:no_httpd_group])
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].empty?
    assert_equal res[:memory]["_counter_database_reads"][:value], 100
    assert_equal res[:memory]["_counter_database_writes"][:value], 1000
  end
  
  def test_normal_run
    time = Time.now
    Timecop.travel(time-60*10) do
      @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
      res = @plugin.run()
      first_run_memory = res[:memory]
      
      # now - 10 minutes later
      Timecop.travel(time) do
        @plugin=CouchDBOverallMonitoring.new(nil,first_run_memory,{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
        res = @plugin.run()
        reports = res[:reports]   
        assert_in_delta 10/(10*60).to_f, reports.find { |r| r.keys.include?('database_reads') }.values.first, 0.001
        assert_in_delta 1000/(10*60).to_f, reports.find { |r| r.keys.include?('database_writes') }.values.first, 0.001
        assert_in_delta 2/(10*60).to_f, reports.find { |r| r.keys.include?('httpd_success') }.values.first, 0.001
        assert_in_delta 1/(10*60).to_f, reports.find { |r| r.keys.include?('httpd_error') }.values.first, 0.001
      end
    end # Timecop.travel
  end
  
  def test_basic_auth
    FakeWeb.clean_registry
    FakeWeb.register_uri(:get, "http://testuser:password@127.0.0.1:5984/_stats", :body => FIXTURES[:initial])
    
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984', :couchdb_user => 'testuser', :couchdb_pwd => 'password'})
    res = @plugin.run()
    assert res[:errors].empty?
    assert_equal res[:memory]["_counter_database_reads"][:value], 100
  end
  
  def test_not_authenticated
    FakeWeb.clean_registry
    FakeWeb.register_uri(:get, "http://127.0.0.1:5984/_stats", :body => "Unauthorized", :status => ["401", "Unauthorized"])
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors][0][:subject] == "Stats URL access denied"
  end
  
  def test_not_found
    CouchDBOverallMonitoring::METRICS.each do |metric|
      uri="http://127.0.0.1:5984/_stats"
      FakeWeb.register_uri(:get, uri, :status => ["404", "Not Found"])
    end
    
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_bad_hostname
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://fake',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_no_host
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>nil,:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_no_port
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>nil})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  ###############
  ### Helpers ###
  ###############
  
  def setup_urls
      uri="http://127.0.0.1:5984/_stats"
      FakeWeb.register_uri(:get, uri, 
        [
         {:body => FIXTURES[:initial]},
         {:body => FIXTURES[:second_run]}
        ]
      )
  end
  
  ################
  ### Fixtures ###
  ################
  
  FIXTURES=YAML.load(<<-EOS)
    :initial: |
      {
        "couchdb":{
          "database_reads":{
            "current":100,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":"number of times a document was read from a database"
          },
          "database_writes":{
            "current":1000,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":""
          }
        },
        "httpd_request_methods": {
          "GET": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "POST": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "PUT": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "DELETE": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        },
        "httpd": {
          "requests": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "view_reads": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        },
        "httpd_status_codes": {
            "200": {
              "current": 2,
              "max": 1,
              "mean": 0.00096946194861852,
              "description": "number of HTTP 200 OK responses",
              "stddev": 0.0311210875797858,
              "min": 0,
              "count": 2063
            },
            "400": {
              "current": 0,
              "max": 1,
              "mean": 0.00096946194861852,
              "description": "",
              "stddev": 0.0311210875797858,
              "min": 0,
              "count": 2063
            }
        }
      }
    :second_run: |
      {
        "couchdb":{
          "database_reads":{
            "current":110,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":"number of times a document was read from a database"
          },
          "database_writes":{
            "current":2000,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":""
          }
        },
        "httpd_request_methods": {
          "GET": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "POST": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "PUT": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "DELETE": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        },
        "httpd": {
          "requests": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "view_reads": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        },
        "httpd_status_codes": {
            "200": {
              "current": 4,
              "max": 1,
              "mean": 0.00096946194861852,
              "description": "number of HTTP 200 OK responses",
              "stddev": 0.0311210875797858,
              "min": 0,
              "count": 2063
            },
            "400": {
              "current": 1,
              "max": 1,
              "mean": 0.00096946194861852,
              "description": "",
              "stddev": 0.0311210875797858,
              "min": 0,
              "count": 2063
            }
        }
      }
    :no_httpd_group: |
      {
        "couchdb":{
          "database_reads":{
            "current":100,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":"number of times a document was read from a database"
          },
          "database_writes":{
            "current":1000,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":""
          }
        },
        "httpd_request_methods": {
          "GET": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "POST": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "PUT": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          },
          "DELETE": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        },
        "httpd_status_codes": {
            "200": {
              "current": 2,
              "max": 1,
              "mean": 0.00096946194861852,
              "description": "number of HTTP 200 OK responses",
              "stddev": 0.0311210875797858,
              "min": 0,
              "count": 2063
            },
            "400": {
              "current": 0,
              "max": 1,
              "mean": 0.00096946194861852,
              "description": "",
              "stddev": 0.0311210875797858,
              "min": 0,
              "count": 2063
            }
        }
      }
  EOS
end