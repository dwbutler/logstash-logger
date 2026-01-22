require 'redis'

module LogStashLogger
  module Device
    class Redis < Connectable
      DEFAULT_LIST = 'logstash'

      attr_accessor :list

      def initialize(opts)
        super
        @list = opts.delete(:list) || DEFAULT_LIST
        @buffer_group = @list

        normalize_path(opts)
        delete_unknown_keywords(opts)

        @redis_options = opts
      end

      def connect
        @io = ::Redis.new(@redis_options)
      end

      def reconnect
        @io.client.reconnect
      rescue => e
        log_error(e)
      end

      def with_connection
        connect unless connected?
        yield
      rescue ::Redis::InheritedError
        reconnect
        retry
      rescue => e
        log_error(e)
        close(flush: false)
        raise
      end

      def write_batch(messages, list = nil)
        list ||= @list
        with_connection do
          @io.rpush(list, messages)
        end
      end

      def write_one(message, list = nil)
        write_batch(message, list)
      end

      def close!
        @io && @io.quit
      end

      private

      def normalize_path(opts)
        path = opts.fetch(:path, nil)
        if path
          opts[:db] = path.gsub("/", "").to_i unless path.empty?
          opts.delete(:path)
        end
      end

      def delete_unknown_keywords(opts)
        # due to restrictions in redis client version >= 5
        # Continous error is being logged for unknown keywords, at present there is only one i.e. :sync
        # to prevent that adding following line :)
        opts.delete(:sync)
      end
    end
  end
end
