require 'logger'
require 'logstash-logger/formatter'

module LogStashLogger
  class CeeFormatter < LogStashLogger::Formatter
    def call(severity, time, progname, message)
      event = build_event(message, severity, time)
      "#{event['host']} #{progname}:@cee: #{event.to_json}\n"
    end
  end
end
