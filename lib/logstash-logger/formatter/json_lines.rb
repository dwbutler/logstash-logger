module LogStashLogger
  module Formatter
    class JsonLines < Base
      def call(severity, time, progname, message)
        super
        "#{LogStashLogger::Encoder.instance.call(@event)}\n"
      end
    end
  end
end
