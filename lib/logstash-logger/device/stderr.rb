module LogStashLogger
  module Device
    class Stderr < IO
      def initialize(opts={})
        super({io: $stderr}.merge(opts))
      end

      def close
        # no-op
      end
    end
  end
end
