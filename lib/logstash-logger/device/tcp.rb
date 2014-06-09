require 'openssl'

module LogStashLogger
  module Device
    class TCP < Socket
      attr_reader :ssl_certificate

      def initialize(opts)
        super
        @ssl_certificate = opts[:ssl_certificate]
      end

      protected

      def connect
        if using_ssl?
          ssl_connect
        else
          non_ssl_connect
        end
      end

      def non_ssl_connect
        @io = TCPSocket.new(@host, @port)
      end

      def ssl_connect
        non_ssl_connect
        openssl_cert = OpenSSL::X509::Certificate.new(::File.read(@ssl_certificate))
        @io = OpenSSL::SSL::SSLSocket.new(@io).tap do |socket|
          socket.connect
        end
      end

      def using_ssl?
        !@ssl_certificate.nil?
      end
    end
  end
end
