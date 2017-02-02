Gem::Specification.new do |s|
  s.name             = "system_run"
  s.version          = "1.0"
  s.platform         = Gem::Platform::RUBY
  s.license          = "MIT"
  s.summary          = "Tiny wrapper for running commands. Inspired by systemu."

  s.description      = "see https://github.com/biederfrau/system_run"

  s.files            = Dir['{example/**/*,server/**/*,lib/**/*,cockpit/**/*,contrib/logo*,contrib/Screen*,log/**/*}'] + %w(LICENSE Rakefile system_run.gemspec README.md)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.test_files       = []

  s.required_ruby_version = '>=2.3.0'

  s.authors          = ['Sonja Biedermann']

  s.email            = 's.bdrmnn@gmail.com'
  s.homepage         = 'https://github.com/biederfrau/system_run'
end
