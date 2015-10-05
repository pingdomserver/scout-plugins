class InfluxDbTest < Test::Unit::TestCase
  def test

    name: httpd
    tags: bind=:8086
    ping_req        points_written_ok       query_req       query_resp_bytes        req     write_req       write_req_bytes
    --------        -----------------       ---------       ----------------        ---     ---------       ---------------
      1               1317326                 10002           21079830                92639   82636           406552183


    name: shard
    tags: engine=b1, id=24, path=/var/opt/influxdb/data/apm_production/default/24
    fields_create   series_create   write_points_ok write_req
    -------------   -------------   --------------- ---------
      18              33895           3964244         248118


    name: write
    -----------
      point_req       point_req_local point_req_remote        req     write_ok
    1317326         1317326         2634652                 82636   82636


    name: runtime
    -------------
      Alloc           Frees           HeapAlloc       HeapIdle        HeapInUse       HeapObjects     HeapReleased    HeapSys         Lookups Mallocs         NumGC   NumGoroutine    PauseTotalNs    Sys             TotalAlloc
    229131808       607485768       229131808       94240768        283344896       2282469         0               377585664       59680   609768237       1186    102             2752144713      399555992       138734240032

  end
end
