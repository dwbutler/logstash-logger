# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'logstash-logger/version'

Gem::Specification.new do |gem|
  gem.name          = "logstash-logger"
  gem.version       = LogStashLogger::VERSION
  gem.authors       = ["David Butler"]
  gem.email         = ["dwbutler@ucla.edu"]
  gem.description   = %q{Ruby logger that writes directly to LogStash}
  gem.summary       = %q{LogStash Logger for ruby}
  gem.homepage      = "http://github.com/dwbutler/logstash-logger"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'logstash-event', '~> 1.2'

  gem.add_development_dependency 'rails'
  gem.add_development_dependency 'redis'
  gem.add_development_dependency 'ruby-kafka'
  gem.add_development_dependency 'aws-sdk-kinesis'
  gem.add_development_dependency 'aws-sdk-firehose'

  if defined?(JRUBY_VERSION)
    gem.add_development_dependency 'SyslogLogger'
  else
    gem.add_development_dependency 'syslog'
  end

  gem.add_development_dependency 'rspec', '>= 3'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'wwtd'
  gem.add_development_dependency 'appraisal'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'rubocop-performance'
  gem.add_development_dependency 'rubocop-rails'
  gem.add_development_dependency 'rubocop-rake'
  gem.add_development_dependency 'rubocop-rspec'

  gem.required_ruby_version = '>= 3.2'
end
