module LogStashLogger
  module Device
    class UDP < Socket
      def connect
        @io = UDPSocket.new.tap {|socket| socket.connect(@host, @port)}
      end
    end
  end
end
