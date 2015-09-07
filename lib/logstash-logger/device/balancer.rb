module LogStashLogger
  module Device
    class Balancer < Base
      attr_reader :devices

      def initialize(opts)
        @io = self
        @devices = create_devices(opts[:outputs])
        self.class.delegate_to_all(:close, :flush)
        self.class.delegate_to_one(:write)
      end

      private

      def create_devices(opts)
        opts.map { |device_opts| Device.new(device_opts) }
      end

      def self.delegate_to_all(*methods)
        methods.each do |m|
          define_method(m) do |*args|
            devices.each { |device| device.send(m, *args) }
          end
        end
      end

      def self.delegate_to_one(*methods)
        methods.each do |m|
          define_method(m) do |*args|
            select_device.send(m, *args)
          end
        end
      end

      def select_device
        devices.sample
      end
    end
  end
end
