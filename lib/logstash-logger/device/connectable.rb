module LogStashLogger
  module Device
    class Connectable < Base
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

      # Implemented by subclasses
      def connect
        fail NotImplementedError
      end

      def reconnect
        @io = nil
        connect
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
