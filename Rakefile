require 'rake'
require 'rubygems/package_task'

spec = eval(File.read('system_run.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
  `rm pkg/* -rf`
  `ln -sf #{pkg.name}.gem pkg/system_run.gem`
end

task :push => :gem do |r|
  `gem push pkg/system_run.gem`
end

task :install => :gem do |r|
  `sudo gem install pkg/system_run.gem`
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task :test => :spec
rescue LoadError
end
