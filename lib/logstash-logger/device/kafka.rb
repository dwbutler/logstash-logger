require 'poseidon'

module LogStashLogger
  module Device
    class Kafka < Connectable

      DEFAULT_HOST = 'localhost'
      DEFAULT_PORT = 9092
      DEFAULT_TOPIC = 'logstash'
      DEFAULT_PRODUCER = 'logstash-logger'
      DEFAULT_BACKOFF = 1
      DEFAULT_RETRY = 2

      attr_accessor :hosts, :topic, :producer, :backoff

      def initialize(opts)
        super
        host = opts[:host] || DEFAULT_HOST
        port = opts[:port] || DEFAULT_PORT
        @hosts = opts[:hosts] || host.split(',').map { |h| "#{h}:#{port}" }
        @topic = opts[:path] || DEFAULT_TOPIC
        @producer = opts[:producer] || DEFAULT_PRODUCER
        @backoff = opts[:backoff] || DEFAULT_BACKOFF
        @max_retry = opts[:max_retry] || DEFAULT_RETRY
      end

      def connect
        @io = ::Poseidon::Producer.new(@hosts, @producer)
      end

      def reconnect
        @io.close
        connect
      end

      def with_connection
        retry_cpt = 0
        begin
          retry_cpt += 1
          connect unless @io
          yield
        rescue ::Poseidon::Errors::ChecksumError, Poseidon::Errors::UnableToFetchMetadata => e
          unless retry_cpt > @max_retry
            warn "#{self.class} - #{e.class} -> reconnect/retry #{retry_cpt}/#{@max_retry}"
            sleep backoff if backoff
            reconnect
            retry
          end
        rescue => e
          warn "#{self.class} - #{e.class} - #{e.message} -> giving up"
          @io = nil
        end
      end

      def write(message)
        buffer_receive Poseidon::MessageToSend.new(@topic, message)
        buffer_flush(force: true) if @sync
      end

      def write_batch(messages)
        with_connection do
          @io.send_messages messages
        end
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
          write_batch(messages)
        end
      end

    end
  end
end
