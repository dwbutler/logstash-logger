require 'redis'
require 'stud/buffer'

module LogStashLogger
  module Device
    class Redis < Connectable
      include Stud::Buffer

      DEFAULT_LIST = 'logstash'

      attr_accessor :list

      def initialize(opts)
        super
        @list = opts.delete(:list) || DEFAULT_LIST
        @redis_options = opts

        @batch_events = opts.fetch(:batch_events, 50)
        @batch_timeout = opts.fetch(:batch_timeout, 5)

        buffer_initialize max_items: @batch_events, max_interval: @batch_timeout
      end

      def connect
        @io = ::Redis.new(@redis_options)
      end

      def reconnect
        @io.client.reconnect
      end

      def with_connection
        connect unless @io
        yield
      rescue ::Redis::InheritedError
        reconnect
        retry
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
        @io = nil
      end

      def write(message)
        buffer_receive message, @list
        buffer_flush(force: true) if @sync
      end

      def close
        buffer_flush(final: true)
        @io && @io.quit
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
      ensure
        @io = nil
      end

      def flush(*args)
        if args.empty?
          buffer_flush
        else
          messages, list = *args
          with_connection do
            @io.rpush(list, messages)
          end
        end
      end

    end
  end
end
