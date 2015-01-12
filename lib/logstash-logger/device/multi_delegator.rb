# Container to allow writes to multiple devices

# Code originally from:
# http://stackoverflow.com/a/6410202

module LogStashLogger
  module Device
    class MultiDelegator
      attr_reader :targets

      def initialize(*targets)
        @targets = targets
      end

      def self.delegate(*methods)
        methods.each do |m|
          define_method(m) do |*args|
            @targets.map { |t| t.send(m, *args) }
          end
        end
        self
      end

      class <<self
        alias to new
      end
    end
  end
end
