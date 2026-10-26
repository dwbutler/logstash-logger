require 'logger'
require 'socket'
require 'time'

module LogStashLogger
  module Formatter
    HOST = {
      'hostname' => ::Socket.gethostname,
      'ip' => Socket.ip_address_list.reject(&:ipv4_loopback?).reject(&:ipv6_loopback?).map(&:ip_address)
  }.freeze

    class Base < ::Logger::Formatter
      FAILED_TO_FORMAT_MSG = 'Failed to format log event'
      FAILED_TO_FORMAT_TAG = '_logstashlogger_format_failure'
      attr_accessor :error_logger
      include ::LogStashLogger::TaggedLogging::Formatter

      def initialize(customize_event: nil, error_logger: LogStashLogger.configuration.default_error_logger)
        @customize_event = customize_event
        @error_logger = error_logger
        super()
      end

      def call(severity, time, progname, message)
        event = build_event(message, severity, time)
        frame_event(event, progname) unless event.cancelled?
      rescue StandardError => e
        log_error(e)
        fallback_event(severity, time, progname, e)
      end

      private

      # Wraps a built event in this formatter's record framing. Formatters that
      # add a header or trailer override this; the fallback below goes through
      # the same framing.
      def frame_event(event, _progname)
        format_event(event)
      end

      # When a record cannot be built or serialized, emit a well-formed
      # placeholder in this formatter's own framing instead, so the failure never
      # changes how a collector splits the stream into records. Returns nil
      # (which devices drop) if even the placeholder cannot be formatted.
      def fallback_event(severity, time, progname, error)
        event = LogStash::Event.new(
          '@timestamp'.freeze => time.is_a?(Time) ? time : Time.now,
          'message'.freeze => FAILED_TO_FORMAT_MSG,
          'severity'.freeze => severity.to_s,
          'host'.freeze => HOST,
          'tags'.freeze => [FAILED_TO_FORMAT_TAG],
          'error'.freeze => error.class.name
        )
        event.timestamp = event.timestamp.iso8601(3) if event.timestamp.is_a?(Time)
        frame_event(event, progname)
      rescue StandardError => e
        log_error(e)
        nil
      end

      def build_event(message, severity, time)
        data = message
        if data.is_a?(String) && data.start_with?('{'.freeze)
          data = (JSON.parse(message) rescue nil) || message
        end

        event = case data
                  when LogStash::Event
                    data.clone
                  when Hash
                    event_data = { '@timestamp'.freeze => time }
                    data.each do |key, value|
                      case key
                      when :message, 'message'
                        event_data['message'.freeze] = value
                      when :tags, 'tags'
                        event_data['tags'.freeze] = value
                      when :source, 'source'
                        event_data['source'.freeze] = value
                      when :type, 'type'
                        event_data['type'.freeze] = value
                      when :'@timestamp', '@timestamp'
                        # Keep the logger time unless the value is a usable time
                        event_data['@timestamp'.freeze] = usable_time(value) || time
                      else
                        event_data[key] = value
                      end
                    end
                    LogStash::Event.new(event_data)
                  else
                    LogStash::Event.new("@timestamp".freeze => time, "message".freeze => msg2str(data))
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

      # LogStash::Event runs String timestamps through Time.parse, which raises
      # for text that is not a time. Keep every other value exactly as given.
      def usable_time(value)
        return value unless value.is_a?(String)
        Time.parse(value)
        value
      rescue ArgumentError, RangeError
        nil
      end

      def force_utf8_encoding(event)
        original_message = event.instance_variable_get(:@data)['message']
        event.message = original_message.dup.force_encoding(Encoding::UTF_8).scrub
        event
      end

      # Check if the message has encoding issues that would cause JSON serialization problems.
      # This is needed because some Ruby implementations (e.g., JRuby) may not raise
      # exceptions during JSON encoding but produce malformed output instead.
      def message_has_encoding_issue?(event)
        message = event.instance_variable_get(:@data)['message']
        return false unless message.is_a?(String)

        # Check if already valid UTF-8
        return false if message.encoding == Encoding::UTF_8 && message.valid_encoding?

        # Try to encode to UTF-8 to detect issues
        message.encode(Encoding::UTF_8)
        false
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        true
      end

      def log_error(e)
        error_logger.error "[#{self.class}] #{e.class} - #{e.message}"
      end
    end
  end
end
