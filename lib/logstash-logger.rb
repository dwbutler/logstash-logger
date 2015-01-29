require 'logstash-logger/version'

require 'logstash/event'

require 'logstash-logger/device'

require 'logstash-logger/logger'
require 'logstash-logger/formatter'
require 'logstash-logger/configuration'

require 'logstash-logger/railtie' if defined? Rails
