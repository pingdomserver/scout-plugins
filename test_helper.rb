require 'test/unit'
require 'rubygems'
require 'mocha'     # gem install mocha
require 'fakeweb'   # gem install fakeweb
require 'timecop'   # gem install timecop
require 'scout'
begin
  require 'pry'
rescue LoadError
  # not using pry
end

if ENV['TRAVIS'] || ENV['COVERAGE']
  require 'simplecov'

  if ENV['TRAVIS']
    require 'coveralls'
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  end

  SimpleCov.start
end

class Test::Unit::TestCase
  # Reads the code and extracts default options. The argument should be the name of
  #  both the plugin directory and the file. This assumes the directory and filename are the same.
  def parse_defaults(name)
    code=File.read("#{File.dirname(__FILE__)}/#{name}/#{name}.rb")
    @options={}
    raw_options=Scout::PluginOptions.from_yaml(Scout::Plugin.extract_options_yaml_from_code(code))
    raw_options.select{|r|r.has_default?}.each{|o|@options[o.name]=o.default}
    return @options
  end
end
