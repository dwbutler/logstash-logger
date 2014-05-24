class LogStashLogger::Socket
  def initialize(host, port, socket_type = :udp)
    @host = host
    @port = port
    @type = socket_type
    @socket = nil
  end
  
  def write(event)
    begin
      connect unless @socket
      
      @socket.write("#{event.to_json}\n")
    rescue => e
      warn "#{self.class} - #{e.class} - #{e.message}"
      close
      @socket = nil
    end
  end
  
  def close
    @socket && @socket.close
  rescue => e
    warn "#{self.class} - #{e.class} - #{e.message}"
  end
  
  private
  def connect
    @socket = case @type
    when :udp then UDPSocket.new.tap {|s| s.connect(@host, @port)}
    when :tcp then TCPSocket.new(@host, @port)
    end
  end
end