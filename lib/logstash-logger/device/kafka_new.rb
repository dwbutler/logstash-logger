module LogStashLogger
  module Device
    class KafkaNew < Connectable
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

      attr_reader :topic, :brokers, :cert_bundle, :kafka_tls_configurator


      # TODO: support client_id
      def initialize(opts = {}, kafka_tls_configurator = TLSConfiguration)
        require 'ruby-kafka'

        @kafka_tls_configurator = kafka_tls_configurator
        @brokers = make_brokers_array(opts[:brokers])
        make_cert_bundle(opts)
      end

      def connect
        connect_opts = @cert_bundle.merge({ seed_brokers: @brokers })
        ::Kafka.new(connect_opts)
      end

      private

      def make_brokers_array(opt)
        case opt
        when Array
          opt
        when String
          opt.split("\s")
        end
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
