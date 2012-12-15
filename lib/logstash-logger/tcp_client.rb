class LogStashLogger::TCPClient
  def initialize(host, port)
    @host = host
    @port = port
  end
  
  def write(event)
    begin
      connect unless @socket
      
      @socket.write("#{event.to_hash.to_json}\n")
    rescue => e
      warn "LogStashLogger::TCPClient - #{e.class} - #{e.message}"
      @socket && @socket.close rescue nil
      @socket = nil
    end
  end
  
  private
  def connect
    @socket = TCPSocket.new(@host, @port)
  end
end