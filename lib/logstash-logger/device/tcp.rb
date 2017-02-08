require 'openssl'

module LogStashLogger
  module Device
    class TCP < Socket
      attr_reader :ssl_certificate

      def initialize(opts)
        super

        @ssl_certificate = opts[:ssl_certificate]
        @ssl_context = opts.fetch(:ssl_context, nil)
        @use_ssl = !!(@ssl_certificate || opts[:ssl_context])
        @use_ssl = opts[:ssl_enable] if opts.has_key? :ssl_enable
      end

      def ssl_context
        return unless use_ssl?
        @ssl_context || certificate_context
      end

      def use_ssl?
        @use_ssl
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
        @io = OpenSSL::SSL::SSLSocket.new(@io, ssl_context)
        @io.connect
        if ssl_context && ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
          @io.post_connection_check(@host)
        end
      end

      def certificate_context
        return unless @ssl_certificate
        @certificate_context ||= OpenSSL::SSL::SSLContext.new.tap do |ctx|
          ctx.set_params(cert: @ssl_certificate)
        end
      end
    end
  end
end
