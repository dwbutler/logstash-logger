module LogStashLogger
  module Device
    class Stdout < IO
      def initialize(opts={})
        super({io: $stdout}.merge(opts))
      end

      def close
        # no-op
        # Calling $stdout.close would be a bad idea
      end
    end
  end
end
