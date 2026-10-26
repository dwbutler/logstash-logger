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
                    # A copy of the caller's event (same class and state,
                    # cancellation included) whose fields are a new Hash with
                    # String keys. It shares the caller's values, except tags:
                    # tagged-scope tags are appended to them below, so the
                    # copy gets its own. Object#dup does not call the
                    # constructor, unlike LogStash::Event#clone, so subclasses
                    # with other constructor arguments work too.
                    fields = string_keys(data.to_hash)
                    tags = fields['tags'.freeze]
                    fields['tags'.freeze] = tags.dup if tags.is_a?(Array) || tags.is_a?(String)
                    data.dup.tap { |copy| copy.instance_variable_set(:@data, fields) }
                  when Hash
                    event_data = { '@timestamp'.freeze => time }
                    string_keys(data).each do |key, value|
                      case key
                      when 'tags'
                        # Tagged-scope tags are appended to this value below,
                        # so the event gets its own copy and the caller's
                        # object is never modified.
                        event_data['tags'.freeze] = value.dup
                      when '@timestamp'
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

      # JSON member names are Strings, so a Symbol key and the String key the
      # logger or LogStash::Event sets for the same field would be written as
      # two members with one name. Every top-level key becomes a String; when
      # a message has both forms of a key, the String-keyed value is kept.
      def string_keys(hash)
        hash.each_with_object({}) do |(key, value), copy|
          name = key.is_a?(String) ? key : key.to_s
          next if !key.is_a?(String) && hash.key?(name)
          copy[name] = value
        end
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
