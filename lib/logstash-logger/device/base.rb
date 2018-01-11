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
        write_one(message) unless message.nil?
      end

      def write_one(message)
        @io.write(message)
      rescue => e
        if unrecoverable_error?(e)
          log_error(e)
          log_warning("unrecoverable error, aborting write")
        else
          raise
        end
      end

      def write_batch(messages, group = nil)
        messages.each do |message|
          write_one(message)
        end
      end

      def flush
        @io && @io.flush
      end

      def close(opts = {})
        close!
      rescue => e
        log_error(e)
      end

      def close!
        @io && @io.close
      ensure
        @io = nil
      end

      def unrecoverable_error?(e)
        e.is_a?(JSON::GeneratorError)
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
