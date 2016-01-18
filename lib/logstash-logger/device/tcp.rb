require 'openssl'

module LogStashLogger
  module Device
    class TCP < Socket
      attr_reader :ssl_certificate

      def initialize(opts)
        super

        @ssl_certificate = opts[:ssl_certificate]
        @use_ssl = !!(@ssl_certificate || opts[:use_ssl] || opts[:ssl_enable])
        @ssl_context = opts.fetch(:ssl_context, nil)
      end

      def use_ssl?
        @use_ssl || !@ssl_certificate.nil?
      end

      def connect
        if use_ssl?
          ssl_connect
        else
          non_ssl_connect
        end

        @io
      end

      protected

      def non_ssl_connect
        @io = TCPSocket.new(@host, @port).tap do |socket|
          socket.sync = sync unless sync.nil?
        end
      end

      def ssl_connect
        non_ssl_connect
        #openssl_cert = OpenSSL::X509::Certificate.new(::File.read(@ssl_certificate))
        if @ssl_context
          @io = OpenSSL::SSL::SSLSocket.new(@io, @ssl_context)
          @io.connect
          @io.post_connection_check(@host)
        else
          warn "[DEPRECATION] 'LogStashLogger::Device::Socket' should be instantiated with a SSL context for hostname verification."
          @io = OpenSSL::SSL::SSLSocket.new(@io)
          @io.connect
        end
      end
    end
  end
end
