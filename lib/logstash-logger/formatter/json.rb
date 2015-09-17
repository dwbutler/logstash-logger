module LogStashLogger
  module Formatter
    class Json < Base
      def call(severity, time, progname, message)
        super
        @event.to_json
      end
    end
  end
end
