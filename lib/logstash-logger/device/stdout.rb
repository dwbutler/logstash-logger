module LogStashLogger
  module Device
    class Stdout < Base
      def initialize(opts={})
        @io = $stdout
      end

      def close
        # no-op
        # Calling $stdout.close would be a bad idea
      end
    end
  end
end
