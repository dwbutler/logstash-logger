require 'socket'

module LogStashLogger
  module Device
    class Unix < Connectable
      def initialize(opts={})
        super
        @path = opts[:path] || fail(ArgumentError, "Path is required")
      end

      def connect
        @io = ::UNIXSocket.new(@path).tap do |socket|
          socket.sync = sync unless sync.nil?
        end
      end
    end
  end
end
