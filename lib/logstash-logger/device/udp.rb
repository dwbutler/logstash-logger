module LogStashLogger
  module Device
    class UDP < Socket
      def connect
        @io = UDPSocket.new.tap do |socket|
          socket.connect(@host, @port)
          socket.sync = sync unless sync.nil?
        end
      end
    end
  end
end
