require 'logger'
require 'socket'
require 'time'

module LogStashLogger
  module Formatter
    HOST = ::Socket.gethostname

    class Base < ::Logger::Formatter
      include ::LogStashLogger::TaggedLogging::Formatter

      def initialize(customize_event = nil)
        @customize_event = customize_event
        super()
      end

      def call(severity, time, progname, message)
        @event = build_event(message, severity, time)
      end

      protected

      def build_event(message, severity, time)
        data = message
        if data.is_a?(String) && data.start_with?('{'.freeze)
          data = (JSON.parse(message) rescue nil) || message
        end

        event = case data
                  when LogStash::Event
                    data.clone
                  when Hash
                    event_data = data.merge("@timestamp".freeze => time)
                    LogStash::Event.new(event_data)
                  else
                    LogStash::Event.new("message".freeze => msg2str(data), "@timestamp".freeze => time)
                end

        event['severity'.freeze] ||= severity
        #event.type = progname

        event['host'.freeze] ||= HOST

        current_tags.each { |tag| event.tag(tag) }
        
        LogStashLogger.configuration.customize_event_block.call(event) if LogStashLogger.configuration.customize_event_block.respond_to?(:call)

        @customize_event.call(event) if @customize_event

        # In case Time#to_json has been overridden
        if event.timestamp.is_a?(Time)
          event.timestamp = event.timestamp.iso8601(3)
        end

        if LogStashLogger.configuration.max_message_size
          event['message'.freeze] = event['message'.freeze].byteslice(0, LogStashLogger.configuration.max_message_size)
        end
        
        event
      end
    end
  end
end
