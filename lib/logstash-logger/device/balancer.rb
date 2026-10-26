module LogStashLogger
  module Device
    class Balancer < Base
      attr_reader :devices

      def initialize(opts)
        super
        @io = self
        @devices = create_devices(opts[:outputs])
        self.class.delegate_to_all(:close, :close!, :flush)
      end

      # Sends the message to one randomly chosen output. If handing the
      # message to that output raises, the error is reported through
      # error_logger and the message goes to the next output instead.
      # Buffered network outputs only enqueue the message here and retry
      # delivery from their own buffer, so their delivery errors never
      # reach this method.
      def write(message)
        first = select_device
        ([first] + (devices - [first])).each do |device|
          begin
            return device.write(message)
          rescue => e
            log_device_error(device, e)
          end
        end
        nil
      end

      private

      def create_devices(opts)
        opts.map { |device_opts| Device.new(device_opts) }
      end

      # Every output receives the call; an error from one output is reported
      # through error_logger and does not stop the others.
      def self.delegate_to_all(*methods)
        methods.each do |m|
          define_method(m) do |*args|
            devices.each do |device|
              begin
                device.send(m, *args)
              rescue => e
                log_device_error(device, e)
              end
            end
          end
        end
      end

      def select_device
        devices.sample
      end

      # Reports an output's error. An error_logger that raises must not stop
      # the failover or the other outputs, so the report goes to stderr
      # instead.
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
