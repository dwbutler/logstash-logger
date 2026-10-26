require 'socket'

module LogStashLogger
  module Device
    class Unix < Connectable
      include WriteDeadline

      def initialize(opts={})
        super
        @path = opts[:path] || fail(ArgumentError, "Path is required")
        @write_timeout = parse_timeout(:write_timeout, opts.fetch(:write_timeout, DEFAULT_WRITE_TIMEOUT))
      end

      def connect
        @io = ::UNIXSocket.new(@path).tap do |socket|
          socket.sync = sync unless sync.nil?
        end
      end
    end
  end
end
