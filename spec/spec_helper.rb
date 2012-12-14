require 'rubygems'
require 'bundler/setup'

require 'logstash-logger'

RSpec.configure do |config|
  config.order = "random"
end