require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../elasticsearch_cluster_node_status.rb', __FILE__)

require 'open-uri'
class ElasticsearchClusterNodeStatusTest < Test::Unit::TestCase
  def setup
    @node_name = 'es_db0'
    @options=parse_defaults("elasticsearch_cluster_node_status")
    setup_urls
  end
  
  def teardown
    FakeWeb.clean_registry    
  end
  
  def test_initial_run
    @plugin = ElasticsearchClusterNodeStatus.new(nil,{},@options.merge(:node_name=>@node_name))
    @res = @plugin.run()
    assert_equal 225, @res[:memory]["gc_collection_time"]
    assert_equal 10, @res[:memory]["gc_collection_count"]
    assert_equal 60, @res[:memory]["gc_parnew_collection_time"]
    assert_equal 9, @res[:memory]["gc_parnew_collection_count"]
    assert_equal 165, @res[:memory]["gc_cms_collection_time"]
    assert_equal 1, @res[:memory]["gc_cms_collection_count"]
  end
  
  def test_second_run
    test_initial_run
    @plugin = ElasticsearchClusterNodeStatus.new(nil,@res[:memory],@options.merge(:node_name=>@node_name))
    res = @plugin.run
    # values for times and counts are 2x the initial run in the fixture data
    assert_equal (res[:memory]["gc_collection_time"]-@res[:memory]["gc_collection_time"]).to_f/(res[:memory]["gc_collection_count"]-@res[:memory]["gc_collection_count"]),
                 res[:reports].find { |r| r.keys.include?(:gc_collection_time) }.values.first
    # should report gc time now
    assert_equal 3, res[:reports].size - @res[:reports].size
  end
  
  ###############
  ### Helpers ###
  ###############
  
  def setup_urls
      uri="http://127.0.0.1:9200/_cluster/nodes/#{@node_name}/stats?all=true"
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
        "cluster_name" : "elasticsearch",
        "nodes" : {
          "K394ZLaSQFaPBzb_AYq2pg" : {
            "name" : "es_db0",
            "indices" : {
              "size" : "502b",
              "size_in_bytes" : 502,
              "docs" : {
                "num_docs" : 0
              },
              "cache" : {
                "field_evictions" : 0,
                "field_size" : "0b",
                "field_size_in_bytes" : 0,
                "filter_count" : 0,
                "filter_evictions" : 0,
                "filter_size" : "0b",
                "filter_size_in_bytes" : 0
              },
              "merges" : {
                "current" : 0,
                "total" : 0,
                "total_time" : "0s",
                "total_time_in_millis" : 0
              }
            },
            "os" : {
              "timestamp" : 1313616315994,
              "uptime" : "-1 seconds",
              "uptime_in_millis" : -1000,
              "load_average" : [ ]
            },
            "process" : {
              "timestamp" : 1313616315994,
              "open_file_descriptors" : 153
            },
            "jvm" : {
              "timestamp" : 1313616315994,
              "uptime" : "1 hour, 28 minutes, 26 seconds and 609 milliseconds",
              "uptime_in_millis" : 5306609,
              "mem" : {
                "heap_used" : "38.1mb",
                "heap_used_in_bytes" : 40028712,
                "heap_committed" : "265.5mb",
                "heap_committed_in_bytes" : 278462464,
                "non_heap_used" : "32mb",
                "non_heap_used_in_bytes" : 33599624,
                "non_heap_committed" : "36.9mb",
                "non_heap_committed_in_bytes" : 38789120
              },
              "threads" : {
                "count" : 41,
                "peak_count" : 61
              },
              "gc" : {
                "collection_count" : 30,
                "collection_time" : "380 milliseconds",
                "collection_time_in_millis" : 380,
                "collectors" : {
                  "ParNew" : {
                    "collection_count" : 29,
                    "collection_time" : "221 milliseconds",
                    "collection_time_in_millis" : 221
                  },
                  "ConcurrentMarkSweep" : {
                    "collection_count" : 1,
                    "collection_time" : "159 milliseconds",
                    "collection_time_in_millis" : 159
                  }
                }
              }
            },
            "network" : {
            },
            "transport" : {
              "server_open" : 21
            },
            "http" : {
              "server_open" : 1
            }
          },
          "zT0BOTMhQGOBmXcklNqjIA" : {
            "name" : "es_db1",
            "indices" : {
              "size" : "1.1kb",
              "size_in_bytes" : 1139,
              "docs" : {
                "num_docs" : 1
              },
              "cache" : {
                "field_evictions" : 0,
                "field_size" : "0b",
                "field_size_in_bytes" : 0,
                "filter_count" : 0,
                "filter_evictions" : 0,
                "filter_size" : "0b",
                "filter_size_in_bytes" : 0
              },
              "merges" : {
                "current" : 0,
                "total" : 0,
                "total_time" : "0s",
                "total_time_in_millis" : 0
              }
            },
            "os" : {
              "timestamp" : 1313616315994,
              "uptime" : "-1 seconds",
              "uptime_in_millis" : -1000,
              "load_average" : [ ]
            },
            "process" : {
              "timestamp" : 1313616315994,
              "open_file_descriptors" : 167
            },
            "jvm" : {
              "timestamp" : 1313616315994,
              "uptime" : "1 hour, 28 minutes, 4 seconds and 305 milliseconds",
              "uptime_in_millis" : 5284305,
              "mem" : {
                "heap_used" : "25.9mb",
                "heap_used_in_bytes" : 27254904,
                "heap_committed" : "265.5mb",
                "heap_committed_in_bytes" : 278462464,
                "non_heap_used" : "30.3mb",
                "non_heap_used_in_bytes" : 31796400,
                "non_heap_committed" : "36.9mb",
                "non_heap_committed_in_bytes" : 38789120
              },
              "threads" : {
                "count" : 43,
                "peak_count" : 54
              },
              "gc" : {
                "collection_count" : 12,
                "collection_time" : "270 milliseconds",
                "collection_time_in_millis" : 270,
                "collectors" : {
                  "ParNew" : {
                    "collection_count" : 11,
                    "collection_time" : "89 milliseconds",
                    "collection_time_in_millis" : 89
                  },
                  "ConcurrentMarkSweep" : {
                    "collection_count" : 1,
                    "collection_time" : "181 milliseconds",
                    "collection_time_in_millis" : 181
                  }
                }
              }
            },
            "network" : {
            },
            "transport" : {
              "server_open" : 21
            },
            "http" : {
              "server_open" : 0
            }
          },
          "FP0mHgloR2alksR1yVFvuw" : {
            "name" : "es_db3",
            "indices" : {
              "size" : "1kb",
              "size_in_bytes" : 1093,
              "docs" : {
                "num_docs" : 1
              },
              "cache" : {
                "field_evictions" : 0,
                "field_size" : "0b",
                "field_size_in_bytes" : 0,
                "filter_count" : 0,
                "filter_evictions" : 0,
                "filter_size" : "0b",
                "filter_size_in_bytes" : 0
              },
              "merges" : {
                "current" : 0,
                "total" : 0,
                "total_time" : "0s",
                "total_time_in_millis" : 0
              }
            },
            "os" : {
              "timestamp" : 1313616315994,
              "uptime" : "-1 seconds",
              "uptime_in_millis" : -1000,
              "load_average" : [ ]
            },
            "process" : {
              "timestamp" : 1313616315994,
              "open_file_descriptors" : 185
            },
            "jvm" : {
              "timestamp" : 1313616315994,
              "uptime" : "56 minutes, 38 seconds and 492 milliseconds",
              "uptime_in_millis" : 3398492,
              "mem" : {
                "heap_used" : "13.8mb",
                "heap_used_in_bytes" : 14474688,
                "heap_committed" : "265.5mb",
                "heap_committed_in_bytes" : 278462464,
                "non_heap_used" : "29.7mb",
                "non_heap_used_in_bytes" : 31195192,
                "non_heap_committed" : "36.9mb",
                "non_heap_committed_in_bytes" : 38793216
              },
              "threads" : {
                "count" : 48,
                "peak_count" : 53
              },
              "gc" : {
                "collection_count" : 10,
                "collection_time" : "225 milliseconds",
                "collection_time_in_millis" : 225,
                "collectors" : {
                  "ParNew" : {
                    "collection_count" : 9,
                    "collection_time" : "60 milliseconds",
                    "collection_time_in_millis" : 60
                  },
                  "ConcurrentMarkSweep" : {
                    "collection_count" : 1,
                    "collection_time" : "165 milliseconds",
                    "collection_time_in_millis" : 165
                  }
                }
              }
            },
            "network" : {
            },
            "transport" : {
              "server_open" : 21
            },
            "http" : {
              "server_open" : 0
            }
          }
        }
      }
    # values for times and counts are 2x the initial run
    :second_run: |
      {
        "cluster_name" : "elasticsearch",
        "nodes" : {
          "K394ZLaSQFaPBzb_AYq2pg" : {
            "name" : "es_db0",
            "indices" : {
              "size" : "502b",
              "size_in_bytes" : 502,
              "docs" : {
                "num_docs" : 0
              },
              "cache" : {
                "field_evictions" : 0,
                "field_size" : "0b",
                "field_size_in_bytes" : 0,
                "filter_count" : 0,
                "filter_evictions" : 0,
                "filter_size" : "0b",
                "filter_size_in_bytes" : 0
              },
              "merges" : {
                "current" : 0,
                "total" : 0,
                "total_time" : "0s",
                "total_time_in_millis" : 0
              }
            },
            "os" : {
              "timestamp" : 1313616315994,
              "uptime" : "-1 seconds",
              "uptime_in_millis" : -1000,
              "load_average" : [ ]
            },
            "process" : {
              "timestamp" : 1313616315994,
              "open_file_descriptors" : 153
            },
            "jvm" : {
              "timestamp" : 1313616315994,
              "uptime" : "1 hour, 28 minutes, 26 seconds and 609 milliseconds",
              "uptime_in_millis" : 5306609,
              "mem" : {
                "heap_used" : "38.1mb",
                "heap_used_in_bytes" : 40028712,
                "heap_committed" : "265.5mb",
                "heap_committed_in_bytes" : 278462464,
                "non_heap_used" : "32mb",
                "non_heap_used_in_bytes" : 33599624,
                "non_heap_committed" : "36.9mb",
                "non_heap_committed_in_bytes" : 38789120
              },
              "threads" : {
                "count" : 41,
                "peak_count" : 61
              },
              "gc" : {
                "collection_count" : 30,
                "collection_time" : "380 milliseconds",
                "collection_time_in_millis" : 380,
                "collectors" : {
                  "ParNew" : {
                    "collection_count" : 29,
                    "collection_time" : "221 milliseconds",
                    "collection_time_in_millis" : 221
                  },
                  "ConcurrentMarkSweep" : {
                    "collection_count" : 1,
                    "collection_time" : "159 milliseconds",
                    "collection_time_in_millis" : 159
                  }
                }
              }
            },
            "network" : {
            },
            "transport" : {
              "server_open" : 21
            },
            "http" : {
              "server_open" : 1
            }
          },
          "zT0BOTMhQGOBmXcklNqjIA" : {
            "name" : "es_db1",
            "indices" : {
              "size" : "1.1kb",
              "size_in_bytes" : 1139,
              "docs" : {
                "num_docs" : 1
              },
              "cache" : {
                "field_evictions" : 0,
                "field_size" : "0b",
                "field_size_in_bytes" : 0,
                "filter_count" : 0,
                "filter_evictions" : 0,
                "filter_size" : "0b",
                "filter_size_in_bytes" : 0
              },
              "merges" : {
                "current" : 0,
                "total" : 0,
                "total_time" : "0s",
                "total_time_in_millis" : 0
              }
            },
            "os" : {
              "timestamp" : 1313616315994,
              "uptime" : "-1 seconds",
              "uptime_in_millis" : -1000,
              "load_average" : [ ]
            },
            "process" : {
              "timestamp" : 1313616315994,
              "open_file_descriptors" : 167
            },
            "jvm" : {
              "timestamp" : 1313616315994,
              "uptime" : "1 hour, 28 minutes, 4 seconds and 305 milliseconds",
              "uptime_in_millis" : 5284305,
              "mem" : {
                "heap_used" : "25.9mb",
                "heap_used_in_bytes" : 27254904,
                "heap_committed" : "265.5mb",
                "heap_committed_in_bytes" : 278462464,
                "non_heap_used" : "30.3mb",
                "non_heap_used_in_bytes" : 31796400,
                "non_heap_committed" : "36.9mb",
                "non_heap_committed_in_bytes" : 38789120
              },
              "threads" : {
                "count" : 43,
                "peak_count" : 54
              },
              "gc" : {
                "collection_count" : 12,
                "collection_time" : "270 milliseconds",
                "collection_time_in_millis" : 270,
                "collectors" : {
                  "ParNew" : {
                    "collection_count" : 11,
                    "collection_time" : "89 milliseconds",
                    "collection_time_in_millis" : 89
                  },
                  "ConcurrentMarkSweep" : {
                    "collection_count" : 1,
                    "collection_time" : "181 milliseconds",
                    "collection_time_in_millis" : 181
                  }
                }
              }
            },
            "network" : {
            },
            "transport" : {
              "server_open" : 21
            },
            "http" : {
              "server_open" : 0
            }
          },
          "FP0mHgloR2alksR1yVFvuw" : {
            "name" : "es_db3",
            "indices" : {
              "size" : "1kb",
              "size_in_bytes" : 1093,
              "docs" : {
                "num_docs" : 1
              },
              "cache" : {
                "field_evictions" : 0,
                "field_size" : "0b",
                "field_size_in_bytes" : 0,
                "filter_count" : 0,
                "filter_evictions" : 0,
                "filter_size" : "0b",
                "filter_size_in_bytes" : 0
              },
              "merges" : {
                "current" : 0,
                "total" : 0,
                "total_time" : "0s",
                "total_time_in_millis" : 0
              }
            },
            "os" : {
              "timestamp" : 1313616315994,
              "uptime" : "-1 seconds",
              "uptime_in_millis" : -1000,
              "load_average" : [ ]
            },
            "process" : {
              "timestamp" : 1313616315994,
              "open_file_descriptors" : 185
            },
            "jvm" : {
              "timestamp" : 1313616315994,
              "uptime" : "56 minutes, 38 seconds and 492 milliseconds",
              "uptime_in_millis" : 3398492,
              "mem" : {
                "heap_used" : "13.8mb",
                "heap_used_in_bytes" : 14474688,
                "heap_committed" : "265.5mb",
                "heap_committed_in_bytes" : 278462464,
                "non_heap_used" : "29.7mb",
                "non_heap_used_in_bytes" : 31195192,
                "non_heap_committed" : "36.9mb",
                "non_heap_committed_in_bytes" : 38793216
              },
              "threads" : {
                "count" : 48,
                "peak_count" : 53
              },
              "gc" : {
                "collection_count" : 20,
                "collection_time" : "500 milliseconds",
                "collection_time_in_millis" : 500,
                "collectors" : {
                  "ParNew" : {
                    "collection_count" : 18,
                    "collection_time" : "120 milliseconds",
                    "collection_time_in_millis" : 120
                  },
                  "ConcurrentMarkSweep" : {
                    "collection_count" : 2,
                    "collection_time" : "330 milliseconds",
                    "collection_time_in_millis" : 330
                  }
                }
              }
            },
            "network" : {
            },
            "transport" : {
              "server_open" : 21
            },
            "http" : {
              "server_open" : 0
            }
          }
        }
      }
  EOS
  
end
