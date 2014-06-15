require 'redis'

module LogStashLogger
  module Device
    class Redis < Connectable
      DEFAULT_LIST = 'logstash'

      attr_accessor :list

      def initialize(opts)
        @list = opts.delete(:list) || DEFAULT_LIST
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
        close
        @io = nil
      end

      def write(message)
        with_connection do
          @io.rpush(@list, message)
        end
      end

      def close
        @io && @io.quit
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
      ensure
        @io = nil
      end

      def flush
        # TO-DO when buffers / batch-push implemented
        # For now it's a no-op (every log message is pushed immediately)
      end
    end
  end
end
