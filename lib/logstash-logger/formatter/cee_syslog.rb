module LogStashLogger
  module Formatter
    class CeeSyslog < Cee
      private

      def frame_event(event, progname)
        "#{build_header(progname)}:#{format_event(event)}\n"
      end

      # The header names this process, never a value taken from the logged
      # content, and always stays on one line.
      def build_header(progname)
        header = HOST['hostname'.freeze].to_s.dup
        header << " #{progname}" if progname
        header.gsub(/[[:cntrl:]]/, ' '.freeze)
      end
    end
  end
end
