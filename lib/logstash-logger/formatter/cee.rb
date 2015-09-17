module LogStashLogger
  module Formatter
    class Cee < Base
      def call(severity, time, progname, message)
        super
        "@cee:#{@event.to_json}"
      end
    end
  end
end
