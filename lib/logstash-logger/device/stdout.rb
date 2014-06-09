module LogStashLogger
  module Device
    class Stdout < Base
      def initialize(opts={})
        @io = $stdout
      end
    end
  end
end
