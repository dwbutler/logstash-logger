require 'logger'
require 'logstash-logger/tagged_logging'

module LogStashLogger
  def self.new(*args)
    opts = extract_opts(*args)
    device = Device.new(opts)

    ::Logger.new(device).tap do |logger|
      logger.instance_variable_set(:@device, device)
      logger.extend(self)
      logger.extend(TaggedLogging)
      logger.formatter = Formatter.new
    end
  end

  def self.extended(base)
    base.instance_eval do
      class << self
        attr_reader :device
      end

      def flush
        !!@device.flush
      end
    end
  end

  def self.config(&block)
    @config = LogStashLogger::Configuration.new(&block) if block_given? || @config.nil?
    @config
  end

  protected

  def self.extract_opts(*args)
    args.flatten!

    if args.length > 1
      if args.all?{|arg| arg.is_a?(Hash)}
        # Array of Hashes
        args
      else
        # Deprecated host/port/type syntax
        puts "[LogStashLogger] (host, port, type) constructor is deprecated. Please use an options hash instead."
        host, port, type = *args
        {host: host, port: port, type: type}
      end
    elsif Hash === args[0]
      args[0]
    else
      fail ArgumentError, "Invalid LogStashLogger options"
    end
  end
end
