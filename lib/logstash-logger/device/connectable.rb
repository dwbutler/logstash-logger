require 'logstash-logger/buffer'

module LogStashLogger
  module Device
    class Connectable < Base
      include LogStashLogger::Buffer

      DEFAULT_FINAL_FLUSH_TIMEOUT = 5

      attr_accessor :buffer_logger

      def initialize(opts = {})
        super

        @buffer_group = nil
        @buffer_max_items = opts[:buffer_max_items]
        @buffer_max_interval = opts[:buffer_max_interval]
        @drop_messages_on_flush_error =
          if opts.key?(:drop_messages_on_flush_error)
            opts.delete(:drop_messages_on_flush_error)
          else
            false
          end

        @drop_messages_on_full_buffer =
          if opts.key?(:drop_messages_on_full_buffer)
            opts.delete(:drop_messages_on_full_buffer)
          else
            true
          end

        @buffer_flush_at_exit =
          if opts.key?(:buffer_flush_at_exit)
            opts.delete(:buffer_flush_at_exit)
          else
            true
          end

        @buffer_logger = opts[:buffer_logger]

        # Deleted from opts so outputs that forward their options (Redis) never
        # receive it.
        @final_flush_timeout = parse_timeout(:final_flush_timeout,
          opts.key?(:final_flush_timeout) ? opts.delete(:final_flush_timeout) : DEFAULT_FINAL_FLUSH_TIMEOUT)

        # Optional cap on the size of a single formatted record. Off by default.
        # Deleted from opts so outputs that forward their options (Redis) never
        # receive it.
        @max_record_bytes = parse_max_record_bytes(opts.delete(:max_record_bytes))

        buffer_initialize(
          max_items: @buffer_max_items,
          max_interval: @buffer_max_interval,
          logger: buffer_logger,
          autoflush: @sync,
          drop_messages_on_flush_error: @drop_messages_on_flush_error,
          drop_messages_on_full_buffer: @drop_messages_on_full_buffer,
          flush_at_exit: @buffer_flush_at_exit,
          final_flush_timeout: @final_flush_timeout
        )
      end

      def write(message)
        return if message.nil?
        if @max_record_bytes
          size = message.to_s.bytesize
          if size > @max_record_bytes
            log_warning("dropping a record of #{size} bytes: over max_record_bytes (#{@max_record_bytes})")
            return
          end
        end
        buffer_receive(message, @buffer_group)
      end

      def flush(*args)
        if args.empty?
          buffer_flush
        else
          messages, group = *args
          write_batch(messages, group)
        end
      end

      def on_full_buffer_receive(data)
        log_warning("Buffer Full - #{data}")
      end

      def on_final_flush_timeout(pending)
        log_warning("final flush gave up after #{@final_flush_timeout} seconds waiting for a running flush; #{pending} records were not sent")
      end

      def on_buffer_drops(count)
        log_warning("Dropped #{count} records because the buffer was full")
      end

      # Closing is final: after the optional final flush, the buffer is shut
      # down, and later writes and flushes are dropped instead of reconnecting.
      def close(opts = {})
        if opts.fetch(:flush, true)
          begin
            buffer_flush(final: true)
          rescue => e
            # A raising on_flush_error hook or buffer logger must not keep
            # the device open
            log_error(e)
          end
        end
        buffer_shutdown

        super
      end

      def to_io
        return nil if buffer_shutdown?
        with_connection do
          super
        end
      end

      def connected?
        !!@io
      end

      def write_one(message)
        with_connection do
          super
        end
      end

      def write_batch(messages, group = nil)
        with_connection do
          super
        end
      end

      # Implemented by subclasses
      def connect
        fail NotImplementedError
      end

      def reset
        reset_buffer
        disconnect
      end

      def reconnect
        disconnect
        connect
      end

      private

      # Drops the connection but keeps the buffer running, so the next flush
      # reconnects. Used to recover from errors; #close is the final shutdown.
      def disconnect
        close!
      rescue => e
        log_error(e)
      end

      # A timeout in seconds, or nil for no timeout. Strings are accepted
      # because options given in a URI query arrive as strings.
      def parse_timeout(name, value)
        return nil if value.nil?
        seconds = value.is_a?(String) ? Float(value) : value
        raise TypeError unless seconds.is_a?(Numeric) && seconds > 0
        seconds
      rescue TypeError, ArgumentError
        raise ArgumentError, "#{name} must be a positive number of seconds or nil: #{value.inspect}"
      end

      def parse_max_record_bytes(value)
        return nil if value.nil? || value.to_s.strip.empty?
        bytes = Integer(value)
        raise ArgumentError, "max_record_bytes must be a positive number of bytes: #{value.inspect}" unless bytes > 0
        bytes
      rescue TypeError
        raise ArgumentError, "max_record_bytes must be a positive number of bytes: #{value.inspect}"
      end

      public

      # Ensure the block is executed with a valid connection
      # Does nothing once the device is closed, so a direct write_one or
      # write_batch call cannot reopen the connection.
      def with_connection()
        return if buffer_shutdown?
        connect unless connected?
        yield
      rescue => e
        log_error(e)
        disconnect
        raise
      end
    end
  end
end
