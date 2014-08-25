module LogStashLogger
  module Device
    class Stdout < Base
      def initialize(opts={})
        super
        @io = STDOUT
        @io.sync = sync unless sync.nil?
      end

      def close
        # no-op
        # Calling STDOUT.close would be a bad idea
      end
    end
  end
end
