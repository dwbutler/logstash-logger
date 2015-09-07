# Container to allow writes to multiple devices

# Code originally from:
# http://stackoverflow.com/a/6410202

module LogStashLogger
  module Device
    class MultiDelegator < Base
      attr_reader :devices

      def initialize(opts)
        @io = self
        @devices = create_devices(opts[:outputs])
        self.class.delegate(:write, :close, :flush)
      end

      private

      def create_devices(opts)
        opts.map do |device_opts|
          Device.new(device_opts)
        end
      end

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
