require 'logstash-logger/version'

require 'logstash/event'

require 'logstash-logger/device'

require 'logstash-logger/logger'
require 'logstash-logger/formatter'
require 'logstash-logger/multi_delegator'

require 'logstash-logger/railtie' if defined? Rails
