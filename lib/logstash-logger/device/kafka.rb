module LogStashLogger
  module Device
    class Kafka < Connectable
      class TLSConfiguration
        attr_reader :ssl_ca_cert, :ssl_client_cert, :ssl_client_cert_key

        def initialize(opts = {})
          @ssl_ca_cert = opts[:ssl_ca_cert]
          @ssl_client_cert = opts[:ssl_client_cert]
          @ssl_client_cert_key = opts[:ssl_client_cert_key]
        end

        def cert_bundle
          @cert_bundle ||= all_cert_params? ? cert_params_as_hash : {}
        end

        def valid?
          all_cert_params? || no_cert_params?
        end

        def invalid?
          !valid?
        end

        private

        def cert_params_as_hash
          { ssl_ca_cert: @ssl_ca_cert,
            ssl_client_cert: @ssl_client_cert,
            ssl_client_cert_key: @ssl_client_cert_key,
          }
        end

        def all_cert_params?
          cert_params_as_hash.values.compact.length == valid_cert_params_length
        end

        def no_cert_params?
          cert_params_as_hash.values.compact.empty?
        end

        def valid_cert_params_length
          cert_params_as_hash.keys.length
        end
      end

      attr_reader :topic, :brokers, :cert_bundle, :kafka_tls_configurator,
        :client_id

      def initialize(opts = {}, kafka_tls_configurator = TLSConfiguration)
        require 'ruby-kafka'
        super(opts)

        @client_id = opts[:client_id]
        @topic = opts[:topic] || raise_no_topic_set!
        @buffer_group = @topic
        @kafka_tls_configurator = kafka_tls_configurator
        @brokers = make_brokers_array(opts[:brokers])
        raise_no_brokers_set! if @brokers.empty?
        make_cert_bundle(opts)
      end

      def connection
        @io ||= ::Kafka.new(**kafka_client_connection_hash)
      end

      def connect
        connection
      end

      def write_one(message, topic=nil)
        topic ||= @topic
        write_messages_to_broker_and_deliver do |producer|
          producer.produce(message, topic: topic)
        end
      end

      def write_batch(messages, topic=nil)
        topic ||= @topic
        write_messages_to_broker_and_deliver do |producer|
          messages.each {|msg| producer.produce(msg, topic: topic) }
        end
      end

      private

      def write_messages_to_broker_and_deliver(&block)
        kproducer = producer
        block.call(kproducer) if block_given?
        kproducer.deliver_messages
      end

      def close!
        begin
          if @producer
            if @producer.respond_to?(:shutdown)
              @producer.shutdown
            elsif @producer.respond_to?(:close)
              @producer.close
            end
          end
        ensure
          @producer = nil
          super
        end
      end

      def kafka_client_connection_hash
        { seed_brokers: @brokers,
          client_id: @client_id,
        }.merge(@cert_bundle)
      end

      def producer
        @producer ||= connection.producer
      end

      def raise_no_topic_set!
        fail ArgumentError, "a topic must be configured"
      end

      def raise_no_brokers_set!
        fail ArgumentError, "brokers must be configured"
      end

      def make_brokers_array(opt)
        brokers =
          case opt
          when Array
            opt.flatten
          when String
            opt.split(/\s+/)
          else
            []
          end
        brokers.compact.map(&:to_s).reject(&:empty?)
      end

      def make_cert_bundle(opts)
        tls_conf = kafka_tls_configurator.new(opts)
        if tls_conf.invalid?
          fail ArgumentError, "all ssl parameters (ssl_ca_cert, ssl_client_cert and ssl_client_cert_key) are required or do use any of them to not use TLS"
        end
        @cert_bundle ||= tls_conf.cert_bundle
      end
    end
  end
end
