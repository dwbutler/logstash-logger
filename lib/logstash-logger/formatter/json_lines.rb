module LogStashLogger
  module Formatter
    class JsonLines < Base
      private

      def format_event(event)
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
