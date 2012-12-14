class LogStashLogger::TCPClient
  # This implementation is shamelessly copied from https://github.com/logstash/logstash/blob/master/lib/logstash/outputs/tcp.rb
  def initialize(host, port)
    @host = host
    @port = port
    connect
    @queue = Queue.new
  end
  
  def write(event)
    #@queue << event
    begin
      connect unless @socket
    
      #event = @queue.pop
      wire_event = "#{event.to_hash.to_json}\n"
      @socket.write(wire_event)
    rescue
      @socket.close
      @socket = nil
    end
  end
  
  public
  def run
    @socket_thread ||= Thread.new do
      loop do
        begin
          connect unless @socket
        
          event = @queue.pop
          wire_event = "#{event.to_hash.to_json}\n"
          @socket.write(wire_event)
        rescue => e
          @socket.close
          @socket = nil
        end
      end
    end
  end

  public
  def receive(event)
    return unless output?(event)

    wire_event = event.to_hash.to_json + "\n"

    if server?
      @client_threads.each do |client_thread|
        client_thread[:client].write(wire_event)
      end

      @client_threads.reject! {|t| !t.alive? }
    else
      begin
        connect unless @client_socket
        @client_socket.write(event.to_hash.to_json)
        @client_socket.write("\n")
      rescue => e
        @logger.warn("tcp output exception", :host => @host, :port => @port,
                     :exception => e, :backtrace => e.backtrace)
        connect
      end
    end
  end
  
  private
  def connect
    @socket = TCPSocket.new(@host, @port)
  end
end