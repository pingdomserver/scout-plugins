require "rake/testtask"
require 'rubocop/rake_task'

Rake::TestTask.new do |test|
  faulty_plugins = %w(
    zz_archive
    tungsten
    apache2_status
    postgresql_monitoring
    apache_analyzer
    redis-info
    mysql_slow_queries
    passenger
    network_throughput
    apache_load
    mysql_replication_monitor
    freeradius_stats
    elasticsearch_cluster_node_status
    mysql_thread_pool_monitor
  )
  excludes = faulty_plugins + %w(vendor)

  test.libs << "test"
  test.test_files = FileList[ "**/test.rb" ].exclude(*excludes)
  test.verbose = true
  test.name = 'unit'
end

# Run the whole shebang
desc 'Run all tests'
task :test => [:lint, :unit]

desc 'Run all tests including code coverage'
task :testc => [:lint, :unitc]

desc 'Run linter'
task :lint => %w{rubocop}

desc 'Run Rubocop lint checks'
task :rubocop do
  Rubocop::RakeTask.new
end

desc 'Run unit tests with code coverage'
task :unitc do
  ENV['COVERAGE'] = 'true'
  task = Rake::Task['unit']
  task.reenable
  task.invoke
end
