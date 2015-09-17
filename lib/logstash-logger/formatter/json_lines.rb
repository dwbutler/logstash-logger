module LogStashLogger
  module Formatter
    class JsonLines < Base
      def call(severity, time, progname, message)
        super
        "#{@event.to_json}\n"
      end
    end
  end
end
