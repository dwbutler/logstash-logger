module LogStashLogger
  module Formatter
    class Json < Base
      private

      def format_event(event)
        event.to_json
      end
    end
  end
end
