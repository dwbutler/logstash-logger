require 'stud/buffer'

module LogStashLogger
  module Device
    class Connectable < Base
      include Stud::Buffer

      def initialize(opts = {})
        super

        if opts[:batch_events]
          warn "The :batch_events option is deprecated. Please use :buffer_max_items instead"
        end

        if opts[:batch_timeout]
          warn "The :batch_timeout option is deprecated. Please use :buffer_max_interval instead"
        end

        @buffer_max_items = opts[:batch_events] || opts[:buffer_max_items]
        @buffer_max_interval = opts[:batch_timeout] || opts[:buffer_max_interval]

        buffer_initialize max_items: @buffer_max_items, max_interval: @buffer_max_interval
      end

      def write(message)
        buffer_receive message
        buffer_flush(force: true) if @sync
      end

      def flush(*args)
        if args.empty?
          buffer_flush
        else
          write_batch(args[0])
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
          messages.each do |message|
            @io.write(message)
          end
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
        # DO NOT RAISE AN EXCEPTION IF YOU CANNOT LOG
        #raise
      end
    end
  end
end
