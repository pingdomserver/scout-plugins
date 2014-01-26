require "rake/testtask"
require 'rubocop/rake_task'

Rake::TestTask.new do |test|
  test.libs << "test"
  test.test_files = [ "**/test.rb" ]
  test.verbose = true
  test.name = 'unit'
end

# Run the whole shebang
desc 'Run all tests'
task :test => [:lint, :unit]

desc 'Run linter'
task :lint => %w{rubocop}

desc 'Run Rubocop lint checks'
task :rubocop do
  Rubocop::RakeTask.new
end

desc 'Run tests with code coverage'
task :coverage do
  ENV['COVERAGE'] = true
  Rake::Task['test'].execute
end
