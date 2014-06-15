require 'socket'

module LogStashLogger
  module Device
    class Socket < Base
      DEFAULT_HOST = '0.0.0.0'

      attr_reader :host, :port

      def initialize(opts)
        super
        @port = opts[:port] || fail(ArgumentError, "Port is required")
        @host = opts[:host] || DEFAULT_HOST
      end

      def write(message)
        with_connection do
          super
        end
      end

      def flush
        return unless connected?
        with_connection do
          super
        end
      end

      def to_io
        with_connection do
          @io
        end
      end

      def connected?
        !!@io
      end

      protected

      # Implemented by TCP and UDP devices
      def connect
        fail NotImplementedError
      end

      # Ensure the block is executed with a valid connection
      def with_connection(&block)
        connect unless @io
        yield
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
        close
        @io = nil
      end
    end
  end
end
