require 'openssl'
require 'ipaddr'

module LogStashLogger
  module Device
    class TCP < Socket
      include WriteDeadline

      DEFAULT_CONNECT_TIMEOUT = 5

      attr_reader :ssl_certificate, :connect_timeout

      def initialize(opts)
        super

        @ssl_certificate = opts[:ssl_certificate]
        @ssl_context = opts[:ssl_context]
        @use_ssl = !!(@ssl_certificate || opts[:ssl_context])
        @use_ssl = opts[:ssl_enable] if opts.has_key? :ssl_enable
        @verify_hostname = opts.fetch(:verify_hostname, true)
        @connect_timeout = parse_timeout(:connect_timeout, opts.fetch(:connect_timeout, DEFAULT_CONNECT_TIMEOUT))
        @write_timeout = parse_timeout(:write_timeout, opts.fetch(:write_timeout, DEFAULT_WRITE_TIMEOUT))
        validate_ssl_certificate! if use_ssl? && @ssl_certificate && !@ssl_context
      end

      # The TLS context used for the connection. Without an operator-supplied
      # :ssl_context, the server certificate is always verified: against the
      # :ssl_certificate file when one is given, otherwise against the system
      # trust store.
      def ssl_context
        return unless use_ssl?
        @ssl_context || certificate_context || default_context
      end

      def use_ssl?
        @use_ssl
      end

      def connect
        if use_ssl?
          ssl_handshake
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

      # The TLS handshake is bounded by connect_timeout, so a server that
      # accepts the TCP connection but never answers cannot hold the thread.
      # One deadline covers both the TCP connect, which io makes, and the
      # handshake.
      def ssl_handshake
        return io.connect unless @connect_timeout
        deadline = monotonic_now + @connect_timeout
        ssl = io
        loop do
          case ssl.connect_nonblock(exception: false)
          when :wait_readable then wait_for_socket(deadline, :read, "TLS handshake", @connect_timeout)
          when :wait_writable then wait_for_socket(deadline, :write, "TLS handshake", @connect_timeout)
          else return
          end
        end
      end

      def tcp_io
        TCPSocket.new(@host, @port, **tcp_timeouts).tap do |socket|
          socket.sync = sync unless sync.nil?
        end
      end

      # connect_timeout also bounds name resolution where Ruby supports it;
      # JRuby's TCPSocket has no resolv_timeout.
      def tcp_timeouts
        timeouts = { connect_timeout: @connect_timeout }
        timeouts[:resolv_timeout] = @connect_timeout if RUBY_ENGINE == 'ruby'
        timeouts
      end

      def ssl_io
        socket = tcp_io
        begin
          OpenSSL::SSL::SSLSocket.new(socket, ssl_context).tap do |ssl|
            # Closing the TLS socket also closes the TCP socket underneath it
            ssl.sync_close = true
            # SNI is only sent for DNS names, never for IP addresses
            ssl.hostname = hostname unless ip_address?(hostname)
          end
        rescue StandardError
          socket.close rescue nil
          raise
        end
      end

      # Trusts the certificate (or CA bundle) in the :ssl_certificate file, in
      # addition to the system trust store.
      def certificate_context
        return unless @ssl_certificate
        @certificate_context ||= verifying_context(ca_file: @ssl_certificate)
      end

      # Used when TLS is enabled without an :ssl_context or :ssl_certificate.
      def default_context
        @default_context ||= verifying_context
      end

      def verifying_context(params = {})
        OpenSSL::SSL::SSLContext.new.tap do |ctx|
          # VERIFY_PEER, hostname verification and the system certificate store
          ctx.set_params(params)
          # Honour an explicit verify_hostname: false
          ctx.verify_hostname = !!@verify_hostname
        end
      end

      def validate_ssl_certificate!
        path = @ssl_certificate.to_s
        unless ::File.file?(path) && ::File.readable?(path)
          raise ArgumentError, "ssl_certificate must be a readable certificate file: #{path.inspect}"
        end
        OpenSSL::X509::Certificate.new(::File.read(path))
      rescue OpenSSL::X509::CertificateError => e
        raise ArgumentError, "ssl_certificate #{path.inspect} is not a PEM or DER certificate: #{e.message}"
      end

      def ip_address?(name)
        IPAddr.new(name.to_s)
        true
      rescue IPAddr::Error
        false
      end

      def verify_hostname?
        return false unless use_ssl?
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
