require 'socket'

module LogStash
  class Connection
    DEFAULT_HOST = '0.0.0.0'
    DEFAULT_TYPE = :udp

    attr_reader :host, :port, :type

    def initialize(opts)
      @host = opts[:host] || DEFAULT_HOST
      @port = opts[:port] || fail(ArgumentError, "Port is required") unless opts[:type] == :stdout
      @type = opts[:type] || DEFAULT_TYPE
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
      @socket = \
        case @type
        when :udp then UDPSocket.new.tap {|socket| socket.connect(@host, @port)}
        when :tcp then TCPSocket.new(@host, @port)
        when :stdout then $stdout
        else fail ArgumentError, 'Invalid connection type'
        end
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
