# frozen_string_literal: true

require 'logger'
require 'socket'
require 'time'

module LogStashLogger
  module Formatter
    HOST = ::Socket.gethostname

    class Base < ::Logger::Formatter
      include ::LogStashLogger::TaggedLogging::Formatter

      def initialize(customize_event: nil)
        @customize_event = customize_event
        super()
      end

      def call(severity, time, _progname, message)
        event = build_event(message, severity, time)
        format_event(event) unless event.cancelled?
      end

      private

      def build_event(message, severity, time)
        data = message
        if data.is_a?(String) && data.start_with?('{')
          data = (JSON.parse(message) rescue nil) || message
        end

        event = case data
                  when LogStash::Event
                    data.clone
                  when Hash
                    event_data = data.clone
                    event_data['message'] = event_data.delete(:message) if event_data.key?(:message)
                    event_data['tags'] = event_data.delete(:tags) if event_data.key?(:tags)
                    event_data['source'] = event_data.delete(:source) if event_data.key?(:source)
                    event_data['type'] = event_data.delete(:type) if event_data.key?(:type)
                    event_data['@timestamp'] = time
                    LogStash::Event.new(event_data)
                  else
                    LogStash::Event.new('message' => msg2str(data), '@timestamp' => time)
                end

        event['severity'] ||= severity
        #event.type = progname

        event['host'] ||= HOST

        current_tags.each { |tag| event.tag(tag) }

        LogStashLogger.configuration.customize_event_block.call(event) if LogStashLogger.configuration.customize_event_block.respond_to?(:call)

        @customize_event.call(event) if @customize_event

        # In case Time#to_json has been overridden
        if event.timestamp.is_a?(Time)
          event.timestamp = event.timestamp.iso8601(3)
        end

        if LogStashLogger.configuration.max_message_size && event['message']
          event['message'] = event['message'].byteslice(0, LogStashLogger.configuration.max_message_size)
        end

        event
      end

      def format_event(event)
        event
      end
    end
  end
end
