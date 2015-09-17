module LogStashLogger
  module Formatter
    class LogStashEvent < Base
      def call(severity, time, progname, message)
        super
      end
    end
  end
end
