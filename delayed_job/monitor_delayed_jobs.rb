$VERBOSE=false

class MonitorDelayedJobs < Scout::Plugin
  ONE_DAY    = 60 * 60 * 24

  OPTIONS=<<-EOS
  path_to_app:
    name: Full Path to the Rails Application
    notes: "The full path to the Rails application (ex: /var/www/apps/APP_NAME/current)."
  rails_env:
    name: Rails environment that should be used
    default: production
  queue_name:
    name: Queue Name
    notes: If specified, only gather the metrics for jobs in this specific queue name. When nil, aggregate metrics from all queues. Not supported with ActiveRecord 2.x. Default is nil
  EOS

  needs 'active_record', 'yaml', 'erb'

  require 'thread'
  # IMPORTANT! Requiring Rubygems is NOT a best practice. See http://scoutapp.com/info/creating_a_plugin#libraries
  # This plugin is an exception because we to subclass ActiveRecord::Base before the plugin's build_report method is run.
  require 'rubygems'
  require 'active_record'
  class DelayedJob < ActiveRecord::Base; end
  DelayedJob.default_timezone = :utc

  def build_report
    app_path = option(:path_to_app)

    # Ensure path to db config provided
    if !app_path or app_path.empty?
      return error("The path to the Rails Application wasn't provided.","Please provide the full path to the Rails Application (ie - /var/www/apps/APP_NAME/current)")
    end

    db_config_path = app_path + '/config/database.yml'

    if !File.exist?(db_config_path)
      return error("The database config file could not be found.", "The database config file could not be found at: #{db_config_path}. Please ensure the path to the Rails Application is correct.")
    end

    db_config = YAML::load(ERB.new(File.read(db_config_path)).result)
    ActiveRecord::Base.establish_connection(db_config[option(:rails_env)])

    # The hash which will store the query commands.
    query_hash = Hash.new

    if DelayedJob.respond_to?(:where)
      # ActiveRecord >= 3.x uses AREL query format
      # All jobs
      query_hash[:total]     = DelayedJob
      # Jobs that are currently being run by workers
      query_hash[:running]   = DelayedJob.where('locked_at IS NOT NULL AND failed_at IS NULL')
      # Jobs that are ready to run but haven't ever been run
      query_hash[:waiting]   = DelayedJob.where('run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc)
      # Jobs that haven't ever been run but are not set to run until later
      query_hash[:scheduled] = DelayedJob.where('run_at > ? AND locked_at IS NULL AND attempts = 0', Time.now.utc)
      # Jobs that aren't running that have failed at least once
      query_hash[:failing]   = DelayedJob.where('attempts > 0 AND failed_at IS NULL AND locked_at IS NULL')
      # Jobs that have permanently failed
      query_hash[:failed]    = DelayedJob.where('failed_at IS NOT NULL')
      # The oldest job that hasn't yet been run, in minutes
      query_hash[:oldest]    = DelayedJob.where('run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc).order(:run_at)

      if option(:queue_name)
        query_hash.keys.each do |key|
          query_hash[key] = query_hash[key].where('queue = ?', option(:queue_name))
        end
      end
    else
      # ActiveRecord 2.x compatible
      # All jobs
      query_hash[:total]     = DelayedJob
      # Jobs that are currently being run by workers
      query_hash[:running]   = DelayedJob.find(:all, :conditions => 'locked_at IS NOT NULL AND failed_at IS NULL')
      # Jobs that are ready to run but haven't ever been run
      query_hash[:waiting]   = DelayedJob.find(:all, :conditions => ['run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc])
      # Jobs that haven't ever been run but are not set to run until later
      query_hash[:scheduled] = DelayedJob.find(:all, :conditions => ['run_at > ? AND locked_at IS NULL AND attempts = 0', Time.now.utc])
      # Jobs that aren't running that have failed at least once
      query_hash[:failing]   = DelayedJob.find(:all, :conditions => 'attempts > 0 AND failed_at IS NULL AND locked_at IS NULL')
      # Jobs that have permanently failed
      query_hash[:failed]    = DelayedJob.find(:all, :conditions => 'failed_at IS NOT NULL')
      # The oldest job that hasn't yet been run, in minutes
      query_hash[:oldest]    = DelayedJob.find(:all, :conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ], :order => :run_at)
    end

    report_hash = Hash.new

    # Execute .count on these query_hash keys and store in report_hash
    query_hash.keys.select{|k| [:total, :running, :waiting, :scheduled, :failing, :failed].include?(k)}.each do |key|
      report_hash[key] = query_hash[key].count
    end

    # The oldest job that hasn't yet been run, in minutes
    if oldest = query_hash[:oldest].first
      report_hash[:oldest] = (Time.now.utc - oldest.run_at) / 60
    else
      report_hash[:oldest] = 0
    end

    report(report_hash)
  end
end
