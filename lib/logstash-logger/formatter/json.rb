module LogStashLogger
  module Formatter
    class Json < Base
      private

      def format_event(event)
        event.to_json
      rescue Encoding::UndefinedConversionError => e
        log_error(e)
        force_utf8_encoding(event).to_json
      end
    end
  end
end
