require 'stud/buffer'

module LogStashLogger
  module Device
    class Connectable < Base
      include Stud::Buffer

      def initialize(opts = {})
        super
        @batch_events = opts[:batch_events] || opts[:max_items]
        @batch_timeout = opts[:batch_timeout] || opts[:max_interval]

        buffer_initialize max_items: @batch_events, max_interval: @batch_timeout
      end

      def write(message)
        buffer_receive message
        buffer_flush(force: true) if @sync
      end

      def flush(*messages)
        if messages.empty?
          buffer_flush
        else
          write_batch(messages)
        end
      end

      def close
        buffer_flush(final: true)
        super
      end

      def to_io
        with_connection do
          @io
        end
      end

      def connected?
        !!@io
      end

      def write_batch(messages)
        with_connection do
          @io.write(messages.join)
        end
      end

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
        connect unless connected?
        yield
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
        @io = nil
        raise
      end
    end
  end
end
