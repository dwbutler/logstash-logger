module LogStashLogger
  module Device
    class Base
      attr_reader :io
      attr_accessor :sync
      attr_accessor :error_logger

      def initialize(opts={})
        @sync = opts[:sync]
        @error_logger = opts.fetch(:error_logger, LogStashLogger.configuration.default_error_logger)
      end

      def to_io
        @io
      end

      def write(message)
        @io.write(message)
      end

      def flush
        @io && @io.flush
      end

      def close
        @io && @io.close
      rescue => e
        log_error(e)
      ensure
        @io = nil
      end

      private

      def log_error(e)
        error_logger.error "[#{self.class}] #{e.class} - #{e.message}"
      end

      def log_warning(message)
        error_logger.warn("[#{self.class}] #{message}")
      end
    end
  end
end
