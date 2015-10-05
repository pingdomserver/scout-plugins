class InfluxDb < Scout::Plugin
  needs 'uri'
  needs 'net/http'
  needs 'json'

  OPTIONS=<<-EOS
    server_url:
      name: HTTP query endpoint
    server_port:
      name: HTTP query port
      default: 8086
  EOS

  def build_report
    uri = URI.parse(option("server_url"))
    http = Net::HTTP.new(uri.host, option("server_port"))
    request = Net::HTTP::Get.new("/query?q=SHOW+STATS")
    response = http.request(request)
    body = response.body
    stats = JSON.parse(body)

    httpd_series = find_series(stats, "httpd")
    report(points_written_ok: find_value_in_series(httpd_series, "points_written_ok"),
           query_req:         find_value_in_series(httpd_series, "query_req"),
           query_resp_bytes:  find_value_in_series(httpd_series, "query_resp_bytes"),
           req:               find_value_in_series(httpd_series, "req"),
           write_req:         find_value_in_series(httpd_series, "write_req"),
           write_req_bytes:   find_value_in_series(httpd_series, "write_req_bytes"),
          )

    runtime_series = find_series(stats, "runtime")
    report( alloc:          find_value_in_series(runtime_series, "Alloc"),
            frees:          find_value_in_series(runtime_series, "Frees"),
            heap_alloc:     find_value_in_series(runtime_series, "HealAlloc"),
            heap_idle:      find_value_in_series(runtime_series, "HeapIdle"),
            heap_in_use:    find_value_in_series(runtime_series, "HeapInUse"),
            heap_objects:   find_value_in_series(runtime_series, "HeapObjects"),
            heap_released:  find_value_in_series(runtime_series, "HeapReleased"),
            heap_sys:       find_value_in_series(runtime_series, "HeapSys"),
            lookups:        find_value_in_series(runtime_series, "Lookups"),
            num_gc:         find_value_in_series(runtime_series, "NumGC"),
            num_goroutine:  find_value_in_series(runtime_series, "NumGoroutine"),
            pause_total_ns: find_value_in_series(runtime_series, "PauseTotalNs"),
            sys:            find_value_in_series(runtime_series, "Sys"),
            total_alloc:    find_value_in_series(runtime_series, "TotalAlloc"),
    )
  end

  def find_series(stats, series)
    stats["results"].first["series"].find{ |s| s["name"] == series }
  end

  def find_value_in_series(series, column)
    ix = series["columns"].find_index{|c| c == column }
    series["values"].first[ix]
  end
end

