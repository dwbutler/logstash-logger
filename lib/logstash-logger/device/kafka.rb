require 'poseidon'
require 'stud/buffer'

module LogStashLogger
  module Device
    class Kafka < Connectable
      include Stud::Buffer

      DEFAULT_HOST = 'localhost'
      DEFAULT_PORT = 9092
      DEFAULT_TOPIC = 'logstash'
      DEFAULT_PRODUCER = 'logstash-logger'
      DEFAULT_BACKOFF = 1

      attr_accessor :hosts, :topic, :producer, :backoff

      def initialize(opts)
        super
        host = opts[:host] || DEFAULT_HOST
        port = opts[:port] || DEFAULT_PORT
        @hosts = opts[:hosts] || host.split(',').map { |h| "#{h}:#{port}" }
        @topic = opts[:path] || DEFAULT_TOPIC
        @producer = opts[:producer] || DEFAULT_PRODUCER
        @backoff = opts[:backoff] || DEFAULT_BACKOFF

        @batch_events = opts.fetch(:batch_events, 50)
        @batch_timeout = opts.fetch(:batch_timeout, 5)

        buffer_initialize max_items: @batch_events, max_interval: @batch_timeout
      end

      def connect
        @io = ::Poseidon::Producer.new(@hosts, @producer)
      end

      def reconnect
        @io.close
        connect
      end

      def with_connection
        connect unless @io
        yield
      rescue ::Poseidon::Errors::ChecksumError, Poseidon::Errors::UnableToFetchMetadata => e
        warn "#{self.class} - #{e.class} -> reconnect/retry"
        sleep backoff if backoff
        reconnect
        retry
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message} -> giving up"
        @io = nil
      end

      def write(message)
        buffer_receive Poseidon::MessageToSend.new(@topic, message)
        buffer_flush(force: true) if @sync
      end

      def close
        buffer_flush(final: true)
        @io && @io.close
      rescue => e
        warn "#{self.class} - #{e.class} - #{e.message}"
      ensure
        @io = nil
      end

      def flush(*args)
        if args.empty?
          buffer_flush
        else
          messages = *args.first
          with_connection do
            @io.send_messages messages
          end
        end
      end

    end
  end
end
