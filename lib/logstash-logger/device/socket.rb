require 'socket'

module LogStashLogger
  module Device
    class Socket < Connectable
      DEFAULT_HOST = '0.0.0.0'

      attr_reader :host, :port

      def initialize(opts)
        super
        @port = opts[:port] || fail(ArgumentError, "Port is required")
        @host = opts[:host] || DEFAULT_HOST
      end

      def unrecoverable_error?(e)
        e.is_a?(Errno::EMSGSIZE)
      end
    end
  end
end
