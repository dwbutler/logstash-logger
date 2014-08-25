module LogStashLogger
  module Device
    class Stdout < Base
      def initialize(opts={})
        super
        @io = opts[:io] || $stdout
        @io.sync = sync unless sync.nil?
      end

      def close
        # no-op
        # Calling $stdout.close would be a bad idea
      end
    end
  end
end
