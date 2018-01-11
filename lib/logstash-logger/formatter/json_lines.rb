module LogStashLogger
  module Formatter
    class JsonLines < Base
      private

      def format_event(event)
        "#{event.to_json}\n"
      end
    end
  end
end
