# =================================================================================
# celery_tasks
#
# Created by Erik Wickstrom on 2011-10-14.
# =================================================================================

class CeleryTasks < Scout::Plugin
  needs 'rubygems'
  needs 'json'
  needs 'net/http'

  OPTIONS=<<-EOS
    celerymon_url:
        default: http://localhost:8989        notes: The base URL of your Celerymon server.    frequency:        default: minute
        notes: The frequency at which sample rates should be calculated (ie "7 failures per minute").  Valid options are minute and second.
  EOS

  def build_report
    if option(:frequency) == "second"
        frequency = :second
    else
        frequency = :minute
    end

    results = Hash.new {0}
    task_names = get_task_names.compact
    for task_name in task_names
        tasks = get_tasks_for_worker(task_name)
        for task in tasks
            if task[1]["state"] == "SUCCESS"
                results[task_name] += 1
            end
        end
    end

    # Take up to the 20 busiest tasks
    results = results.sort_by { |name, value| value }
    results = results.reverse[0, 20]
    for task_name in results
        counter(task_name[0], task_name[1], :per => frequency)
    end
  end

  def get_tasks
     url = "#{option('celerymon_url').to_s.strip}/api/task/?limit=0"
     result = query_api(url)
  end

  def get_tasks_for_worker(task_name)
     url = "#{option('celerymon_url').to_s.strip}/api/task/name/#{task_name}/"
     result = query_api(url)
  end


  def get_workers
     url = "#{option('celerymon_url').to_s.strip}/api/worker/"
     result = query_api(url)
  end

  def get_task_names
     url = "#{option('celerymon_url').to_s.strip}/api/task/name/"
     result = query_api(url)
  end

  def query_api(url)
     resp = Net::HTTP.get_response(URI.parse(url))
     data = resp.body

     # we convert the returned JSON data to native Ruby
     # data structure - a hash
     result = JSON.parse(data)

     # if the hash has 'Error' as a key, we raise an error
     #if result.has_key? 'Error'
     #   raise "web service error"
     #end
     return result
  end
end
