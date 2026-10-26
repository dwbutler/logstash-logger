# Container to allow writes to multiple devices

# Code originally from:
# http://stackoverflow.com/a/6410202

module LogStashLogger
  module Device
    class MultiDelegator < Base
      attr_reader :devices

      def initialize(opts)
        super
        @io = self
        @devices = create_devices(opts)
        self.class.delegate(:write, :close, :close!, :flush)
      end

      private

      def create_devices(opts)
        output_configurations = opts.delete(:outputs)
        output_configurations.map do |device_opts|
          device_opts = opts.merge(device_opts)
          Device.new(device_opts)
        end
      end

      # Each output is an independent delivery path: an error from one output
      # is reported through error_logger and the remaining outputs still
      # receive the call.
      def self.delegate(*methods)
        methods.each do |m|
          define_method(m) do |*args|
            @devices.each do |device|
              begin
                device.send(m, *args)
              rescue => e
                log_device_error(device, e)
              end
            end
          end
        end
      end

      # Reports an output's error. An error_logger that raises must not stop
      # delivery to the other outputs, so the report goes to stderr instead.
      def log_device_error(device, e)
        message = "[#{self.class}] #{device.class} - #{e.class} - #{e.message}"
        begin
          error_logger.error message
        rescue => logger_error
          warn("#{message} (error_logger failed: #{logger_error.class})") rescue nil
        end
      end
    end
  end
end
