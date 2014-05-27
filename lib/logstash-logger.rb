require 'logstash-logger/version'

require 'logstash/event'

require 'logstash/tagged_logging'
require 'logstash/connection'

require 'logstash-logger/logger'
require 'logstash-logger/formatter'

require 'logstash-logger/railtie' if defined? Rails