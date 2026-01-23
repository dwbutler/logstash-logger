require 'fileutils'
module LogStashLogger
  module Device
    class File < Base
      def initialize(opts)
        super
        @path = opts[:path] || fail(ArgumentError, "Path is required")
        @shift_age = opts[:shift_age]
        @shift_size = opts[:shift_size]
        @shift_period_suffix = opts[:shift_period_suffix]
        @use_log_device = opts.key?(:shift_age) || opts.key?(:shift_size) || opts.key?(:shift_period_suffix)
        open
      end

      def open
        unless ::File.exist? ::File.dirname @path
          ::FileUtils.mkdir_p ::File.dirname @path
        end

        if @use_log_device
          require 'logger'
          log_device_options = { binmode: true }
          log_device_options[:shift_age] = @shift_age unless @shift_age.nil?
          log_device_options[:shift_size] = @shift_size unless @shift_size.nil?
          log_device_options[:shift_period_suffix] = @shift_period_suffix unless @shift_period_suffix.nil?
          @io = ::Logger::LogDevice.new(@path, **log_device_options)
          @io.dev.sync = self.sync unless self.sync.nil?
        else
          @io = ::File.open @path, ::File::WRONLY | ::File::APPEND | ::File::CREAT
          @io.binmode
          @io.sync = self.sync unless self.sync.nil?
        end
      end

      def to_io
        @io.respond_to?(:dev) ? @io.dev : @io
      end
    end
  end
end
