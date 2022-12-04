# frozen_string_literal: true

require 'openssl'

module LogStashLogger
  module Device
    class TCP < Socket
      attr_reader :ssl_certificate

      def initialize(opts)
        super

        @ssl_certificate = opts[:ssl_certificate]
        @ssl_context = opts[:ssl_context]
        @use_ssl = !!(@ssl_certificate || opts[:ssl_context])
        @use_ssl = opts[:ssl_enable] if opts.has_key? :ssl_enable
        if opts.has_key?(:use_ssl)
          @use_ssl = opts[:use_ssl]
          warn '[LogStashLogger] The use_ssl option is deprecated. Use ssl_enable instead.'
        end
        @verify_hostname = opts.fetch(:verify_hostname, true)
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
          io.connect
          verify_hostname!
        end
        io
      end

      def io
        @io ||= if use_ssl?
          ssl_io
        else
          tcp_io
        end
      end

      protected

      def tcp_io
        TCPSocket.new(@host, @port).tap do |socket|
          socket.sync = sync unless sync.nil?
        end
      end

      def ssl_io
        ssl_context ?
          OpenSSL::SSL::SSLSocket.new(tcp_io, ssl_context) :
          OpenSSL::SSL::SSLSocket.new(tcp_io)
      end

      def certificate_context
        return unless @ssl_certificate
        @certificate_context ||= OpenSSL::SSL::SSLContext.new.tap do |ctx|
          ctx.set_params(cert: @ssl_certificate)
        end
      end

      def verify_hostname?
        return false unless ssl_context
        !! @verify_hostname
      end

      def verify_hostname!
        @io.post_connection_check(hostname) if verify_hostname?
      end

      def hostname
        if String === @verify_hostname
          @verify_hostname
        else
          @host
        end
      end
    end
  end
end
