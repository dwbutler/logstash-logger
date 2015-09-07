require 'logger'
require 'logstash-logger/tagged_logging'

module LogStashLogger
  autoload :MultiLogger, 'logstash-logger/multi_logger'

  def self.new(*args)
    opts = extract_opts(*args)
    build_logger(opts)
  end

  def self.extended(base)
    base.instance_eval do
      class << self
        attr_reader :device
      end

      def flush
        !!(@device.flush if @device.respond_to?(:flush))
      end
    end
  end

  protected

  def self.extract_opts(*args)
    args.flatten!

    if args.length > 1
      if args.all?{|arg| arg.is_a?(Hash)}
        # Deprecated array of hashes
        warn "[LogStashLogger] Passing an array of hashes to the constructor is deprecated. Please replace with an options hash: { type: :multi_delegator, outputs: [...] }"
        { type: :multi_delegator, outputs: args }
      else
        # Deprecated host/port/type constructor
        warn "[LogStashLogger] The (host, port, type) constructor is deprecated. Please use an options hash instead."
        host, port, type = *args
        { host: host, port: port, type: type }
      end
    elsif Hash === args[0]
      args[0]
    else
      fail ArgumentError, "Invalid LogStashLogger options"
    end
  end

  def self.build_logger(opts)
    case opts[:type]
    when :multi_logger
      loggers = opts[:outputs].map {|logger_opts| build_logger(logger_opts) }
      MultiLogger.new(loggers)
    else
      formatter = Formatter.new(opts.delete(:formatter))
      device = Device.new(opts)

      ::Logger.new(device).tap do |logger|
        logger.instance_variable_set(:@device, device)
        logger.extend(self)
        logger.extend(TaggedLogging)
        logger.formatter = formatter
      end
    end
  end
end
