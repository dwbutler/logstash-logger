class LogStashLogger::TCPClient
  def initialize(host, port)
    @host = host
    @port = port
    @socket = nil
  end
  
  def write(event)
    begin
      connect unless @socket
      
      @socket.write("#{event.to_hash.to_json}\n")
    rescue => e
      warn "LogStashLogger::TCPClient - #{e.class} - #{e.message}"
      close
      @socket = nil
    end
  end
  
  def close
    @socket && @socket.close
  rescue => e
    warn "LogStashLogger::TCPClient - #{e.class} - #{e.message}"
  end
  
  private
  def connect
    @socket = TCPSocket.new(@host, @port)
  end
end