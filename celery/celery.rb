# =================================================================================
# celery
#
# Created by Erik Wickstrom on 2011-10-14.
# =================================================================================

class Celery < Scout::Plugin
  needs 'rubygems'
  needs 'json'
  needs 'net/http'

  OPTIONS=<<-EOS
    celerymon_url:        default: http://localhost:8989        notes: The base URL of your Celerymon server.    frequency:
        default: minute
        notes: The frequency at which sample rates should be calculated (ie "7 failures per minute").  Valid options are minute and second.
  EOS

  def build_report
    if option(:frequency) == "second"
        frequency = :second
    else
        frequency = :minute
    end

    tasks = get_tasks()
    results = Hash.new {0}
    for task in tasks
        results[task[1]["state"]] += 1
    end

    workers = get_workers.length
    if workers.zero?
        alert("You don't have any active Celery workers!")
    end

    report(:workers => workers, :task_types => get_task_names.compact.length)
    report(:total_recieved => results["RECEIVED"],
           :total_started => results["STARTED"],
           :total_successes => results["SUCCESS"],
           :total_retry => results["RETRY"],
           :total_failures => results["FAILURE"])
    counter(:failures, results["FAILURE"], :per => frequency)
    counter(:successes, results["SUCCESS"], :per => frequency)
    counter(:started, results["STARTED"], :per => frequency)
    counter(:recieved, results["RECEIVED"], :per => frequency)
    counter(:retry, results["RETRY"], :per => frequency)
  end

  def get_tasks
     url = "#{option('celerymon_url').to_s.strip}/api/task/?limit=0"
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
