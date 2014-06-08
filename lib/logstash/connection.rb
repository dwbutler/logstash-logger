require 'socket'

module LogStash
  class Connection
    DEFAULT_HOST = '0.0.0.0'
    DEFAULT_TYPE = :udp

    attr_reader :host, :port, :type, :ssl_certificate

    def initialize(opts)
      @type = opts[:type] || DEFAULT_TYPE

      if [:udp, :tcp].include?(type)
        @port = opts[:port] || fail(ArgumentError, "Port is required")
        @host = opts[:host] || DEFAULT_HOST
      end

      @ssl_certificate = opts[:ssl_certificate]

      @socket = nil
    end

    def write(message)
      with_connection do
        @socket.write message
      end
    end

    def flush
      return unless connected?
      with_connection do
        @socket.flush
      end
    end

    def close
      @socket && @socket.close
    rescue => e
      warn "#{self.class} - #{e.class} - #{e.message}"
    ensure
      @socket = nil
    end

    def connected?
      !!@socket
    end

    protected

    def connect
      return ssl_connect if using_ssl?
      @socket = \
        case @type
        when :udp then UDPSocket.new.tap {|socket| socket.connect(@host, @port)}
        when :tcp then TCPSocket.new(@host, @port)
        when :stdout then $stdout
        else fail ArgumentError, 'Invalid connection type'
        end
    end

    def ssl_connect
      raise "Not available on UDP" if @type == :udp
      tcp_socket = TCPSocket.new(@host, @port)
      openssl_cert = OpenSSL::X509::Certificate.new(::File.read(@ssl_certificate))
      @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket)
      @socket.connect
    end

    def using_ssl?
      !@ssl_certificate.nil?
    end

    def with_connection(&block)
      connect unless @socket
      yield
    rescue => e
      warn "#{self.class} - #{e.class} - #{e.message}"
      close
      @socket = nil
    end
  end
end
