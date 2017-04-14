module LogStashLogger
  module Formatter
    class Json < Base
      def call(severity, time, progname, message)
        super
        LogStashLogger::Encoder.instance.call(@event)
      end
    end
  end
end
