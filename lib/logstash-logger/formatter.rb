require 'logger'
require 'socket'
require 'time'

module LogStashLogger
  HOST = ::Socket.gethostname

  class Formatter < ::Logger::Formatter
    include TaggedLogging::Formatter

    def call(severity, time, progname, message)
      event = build_event(message, severity, time)
      "#{event.to_json}\n"
    end

    protected

    def build_event(message, severity, time)
      data = message
      if data.is_a?(String) && data.start_with?('{')
        data = (JSON.parse(message) rescue nil) || message
      end

      event = case data
                when LogStash::Event
                  data.clone
                when Hash
                  event_data = data.merge("@timestamp" => time)
                  LogStash::Event.new(event_data)
                else
                  LogStash::Event.new("message" => msg2str(data), "@timestamp" => time)
              end

      event['severity'] ||= severity
      #event.type = progname

      event['host'] ||= HOST
      
      event['appname'] ||= Rails.application.class.parent_name.titleize

      current_tags.each do |tag|
        event.tag(tag)
      end

      # In case Time#to_json has been overridden
      if event.timestamp.is_a?(Time)
        event.timestamp = event.timestamp.iso8601(3)
      end

      event
    end
  end
end
