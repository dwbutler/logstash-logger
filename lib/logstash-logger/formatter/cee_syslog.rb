# frozen_string_literal: true

module LogStashLogger
  module Formatter
    class CeeSyslog < Cee
      def call(severity, time, progname, message)
        @progname = progname
        super
      end

      private

      def build_facility(host)
        facility = host.dup
        facility << " #{@progname}" if @progname
        facility
      end

      def format_event(event)
        "#{build_facility(event["host"])}:#{super}\n"
      end
    end
  end
end
