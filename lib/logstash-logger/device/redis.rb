require 'redis'

module LogStashLogger
  module Device
    class Redis < Connectable
      DEFAULT_LIST = 'logstash'

      attr_accessor :list

      def initialize(opts)
        super
        @list = opts.delete(:list) || DEFAULT_LIST

        normalize_path(opts)

        @redis_options = opts
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
        raise
      end

      def write(message)
        buffer_receive message, @list
        buffer_flush(force: true) if @sync
      end

      def write_batch(messages, list = nil)
        with_connection do
          @io.rpush(list, messages)
        end
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
          write_batch(messages, list)
        end
      end
      
      private

      def normalize_path(opts)
        path = opts.fetch(:path, nil)
        if path
          opts[:db] = path.gsub("/", "").to_i unless path.empty?
          opts.delete(:path)
        end
      end

    end
  end
end
