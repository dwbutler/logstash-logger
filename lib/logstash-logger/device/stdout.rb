module LogStashLogger
  module Device
    class Stdout < IO
      def initialize(opts={})
        super(opts.merge(io: STDOUT))
      end

      def close
        # no-op
        # Calling STDOUT.close would be a bad idea
      end
    end
  end
end
