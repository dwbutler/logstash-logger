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
      # Fields of a String (JSON) or Hash message that the log call itself
      # owns. Unless trust_message_fields is set, logged values for them are
      # moved under MOVED_FIELDS_KEY and the call-site values are used.
      CALL_SITE_FIELDS = %w[severity @timestamp @version].freeze
      MOVED_FIELDS_KEY = 'message_fields'.freeze
      # The JSON generator's default max_nesting. The encoding check raises
      # JSON::NestingError for Hashes and Arrays nested deeper than this, and
      # encoding repair leaves them as they are.
      MAX_SCAN_DEPTH = 100
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
                    trusted = LogStashLogger.configuration.trust_message_fields
                    event_data = { '@timestamp'.freeze => time }
                    moved = {}
                    string_keys(data).each do |key, value|
                      if !trusted && CALL_SITE_FIELDS.include?(key)
                        moved[key] = value
                        next
                      end

                      case key
                      when 'tags'
                        event_data['tags'.freeze] = message_tags(value)
                      when '@timestamp'
                        # Reached only when trust_message_fields is set. Keep
                        # the logger time unless the value is a usable time.
                        event_data['@timestamp'.freeze] = usable_time(value) || time
                      else
                        event_data[key] = value
                      end
                    end
                    event_data['severity'.freeze] = severity unless trusted
                    event_data[MOVED_FIELDS_KEY] = moved_fields(moved, event_data) unless moved.empty?
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

      # A message's own message_fields is kept: a Hash is merged with the
      # moved values, its own keys winning, and any other value is kept
      # under message_fields['message_fields'].
      def moved_fields(moved, event_data)
        return moved unless event_data.key?(MOVED_FIELDS_KEY)

        own = event_data[MOVED_FIELDS_KEY]
        own.is_a?(Hash) ? moved.merge(string_keys(own)) : moved.merge(MOVED_FIELDS_KEY => own)
      end

      # Tagged-scope tags are appended to the event's tags, so the event gets
      # its own Array and the caller's object is never modified. A single
      # value, such as a String, becomes the only element instead of having
      # the tagged-scope tags concatenated onto it.
      def message_tags(value)
        case value
        when nil then nil
        when Array then value.dup
        else [value]
        end
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

      # Re-encodes every String in the event as valid UTF-8: keys and values,
      # nested Hashes and Arrays included, so invalid bytes in a tag or any
      # other field cannot stop the record from being serialized.
      def force_utf8_encoding(event)
        data = event.to_hash
        data.replace(utf8_copy(data))
        event
      end

      # Each Hash or Array is copied once, so one that appears several times,
      # or contains itself, maps to a single copy instead of recursing forever.
      def utf8_copy(value, copies = {}.compare_by_identity, depth = 0)
        case value
        when String then utf8_string(value)
        when Hash, Array
          return value if depth > MAX_SCAN_DEPTH
          return copies[value] if copies.key?(value)

          if value.is_a?(Hash)
            copy = copies[value] = {}
            value.each do |k, v|
              copy[unique_key(copy, utf8_copy(k, copies, depth + 1))] = utf8_copy(v, copies, depth + 1)
            end
          else
            copy = copies[value] = []
            value.each { |v| copy << utf8_copy(v, copies, depth + 1) }
          end
          copy
        else value
        end
      end

      # Two keys can repair to the same String ("a\xFF" and "a\xFE" both become
      # "a\uFFFD"). The later one gets a numeric suffix, so no value is lost.
      def unique_key(copy, key)
        return key unless copy.key?(key)

        suffix = 2
        suffix += 1 while copy.key?("#{key}_#{suffix}")
        "#{key}_#{suffix}"
      end

      def utf8_string(string)
        return string unless string_has_encoding_issue?(string)

        if string.encoding == Encoding::UTF_8 || string.encoding == Encoding::BINARY
          string.dup.force_encoding(Encoding::UTF_8).scrub
        else
          string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end
      end

      # Checks every String in the event for encoding issues that would cause
      # JSON serialization problems. This is needed because some Ruby
      # implementations (e.g., JRuby) may not raise exceptions during JSON
      # encoding but produce malformed output instead.
      def event_has_encoding_issue?(event)
        encoding_issue?(event.to_hash)
      end

      # Past MAX_SCAN_DEPTH this raises JSON::NestingError, as the JSON
      # generator does, so a Hash or Array that contains itself ends in the
      # placeholder record instead of recursing forever. Not every JSON
      # encoder checks the nesting itself (ActiveSupport 8.0's does not).
      def encoding_issue?(value, depth = 0)
        case value
        when String then string_has_encoding_issue?(value)
        when Hash, Array
          raise JSON::NestingError, "nesting of #{depth + 1} is too deep" if depth > MAX_SCAN_DEPTH

          if value.is_a?(Hash)
            value.any? { |k, v| encoding_issue?(k, depth + 1) || encoding_issue?(v, depth + 1) }
          else
            value.any? { |v| encoding_issue?(v, depth + 1) }
          end
        else false
        end
      end

      def string_has_encoding_issue?(string)
        return !string.valid_encoding? if string.encoding == Encoding::UTF_8
        return false if string.ascii_only?

        # Try to encode to UTF-8 to detect issues
        string.encode(Encoding::UTF_8)
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
