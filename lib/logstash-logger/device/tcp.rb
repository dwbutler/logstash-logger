require 'openssl'

module LogStashLogger
  module Device
    class TCP < Socket
      attr_reader :ssl_certificate

      def initialize(opts)
        super

        @ssl_certificate = opts[:ssl_certificate]
        @use_ssl = !!(@ssl_certificate || opts[:use_ssl] || opts[:ssl_enable])
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
        @io = OpenSSL::SSL::SSLSocket.new(@io)
        @io.connect
      end
    end
  end
end
