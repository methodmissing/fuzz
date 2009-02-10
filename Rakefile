begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  require 'spec'
end

require 'spec/rake/spectask'

desc 'Default: run specs.'
task :default => :spec

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../'
$LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'

require 'fuzz'

desc "Run the specs under spec"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts << "-c"
end