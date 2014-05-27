require 'socket'

module LogStash
  class Connection
    def initialize(host, port, type = :udp)
      @host = host
      @port = port
      @type = type
      @socket = nil
    end

    def write(event)
      with_connection do
        @socket.puts event.to_json
      end
    end

    def flush
      return unless connected?
      with_connection do
        #@socket.flush
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