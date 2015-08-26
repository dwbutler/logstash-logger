module LogStashLogger
  module Formatter
    class CeeSyslog < Cee
      def call(severity, time, progname, message)
        @cee = super
        @progname = progname

        "#{facility}:#{@cee}\n"
      end

      protected

      def facility
        @facility = "#{@event['host']}"
        @facility << " #{@progname}" if @progname
        @facility
      end
    end
  end
end
