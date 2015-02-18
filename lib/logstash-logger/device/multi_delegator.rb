# Container to allow writes to multiple devices

# Code originally from:
# http://stackoverflow.com/a/6410202

module LogStashLogger
  module Device
    class MultiDelegator < Base
      attr_reader :devices

      def initialize(*devices)
        @io = self
        @devices = devices
        self.class.delegate(:write, :close, :flush)
      end

      private

      def self.delegate(*methods)
        methods.each do |m|
          define_method(m) do |*args|
            @devices.each { |device| device.send(m, *args) }
          end
        end
      end
    end
  end
end
