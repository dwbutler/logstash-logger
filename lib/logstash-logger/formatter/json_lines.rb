module LogStashLogger
  module Formatter
    class JsonLines < Base
      private

      def format_event(event)
        # Proactively check for encoding issues to handle cross-platform differences.
        # Some Ruby implementations (e.g., JRuby) may not raise exceptions during
        # JSON encoding but produce malformed output instead.
        if message_has_encoding_issue?(event)
          log_error(Encoding::InvalidByteSequenceError.new("Invalid encoding in message"))
          return "#{force_utf8_encoding(event).to_json}\n"
        end

        "#{event.to_json}\n"
      rescue Encoding::UndefinedConversionError,
             Encoding::InvalidByteSequenceError,
             JSON::GeneratorError => e
        log_error(e)
        "#{force_utf8_encoding(event).to_json}\n"
      end
    end
  end
end
