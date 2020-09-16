require 'logger'
require 'socket'
require 'time'

module LogStashLogger
  module Formatter
    HOST = ::Socket.gethostname

    class Base < ::Logger::Formatter
      FAILED_TO_FORMAT_MSG = 'Failed to format log event'
      attr_accessor :error_logger
      include ::LogStashLogger::TaggedLogging::Formatter

      def initialize(customize_event: nil, error_logger: LogStashLogger.configuration.default_error_logger)
        @customize_event = customize_event
        @error_logger = error_logger
        super()
      end

      def call(severity, time, _progname, message)
        event = build_event(message, severity, time)
        format_event(event) unless event.cancelled?
      rescue StandardError => e
        log_error(e)
        FAILED_TO_FORMAT_MSG
      end

      private

      def build_event(message, severity, time)
        data = message
        if data.is_a?(String) && data.start_with?('{'.freeze)
          data = (JSON.parse(message) rescue nil) || message
        end

        event = case data
                  when LogStash::Event
                    data.clone
                  when Hash
                    event_data = data.clone
                    event_data['message'.freeze] = event_data.delete(:message) if event_data.key?(:message)
                    event_data['tags'.freeze] = event_data.delete(:tags) if event_data.key?(:tags)
                    event_data['source'.freeze] = event_data.delete(:source) if event_data.key?(:source)
                    event_data['type'.freeze] = event_data.delete(:type) if event_data.key?(:type)
                    event_data['@timestamp'.freeze] = time
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

        if LogStashLogger.configuration.max_message_size && event['message']
          event['message'.freeze] = event['message'.freeze].byteslice(0, LogStashLogger.configuration.max_message_size)
        end

        event
      end

      def format_event(event)
        event
      end

      def force_utf8_encoding(event)
        original_message = event.instance_variable_get(:@data)['message']
        event.message = original_message.force_encoding(Encoding::UTF_8).scrub
        event
      end

      def log_error(e)
        error_logger.error "[#{self.class}] #{e.class} - #{e.message}"
      end
    end
  end
end
