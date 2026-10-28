require 'logger'
require 'logstash-logger/tagged_logging'
require 'logstash-logger/silenced_logging'

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

      def reset
        @device.reset if @device.respond_to?(:reset)
      end
    end
  end


  def self.extract_opts(*args)
    if args.length == 1 && args[0].is_a?(Hash)
      args[0]
    else
      fail ArgumentError, "Invalid LogStashLogger options. Expected a single options hash."
    end
  end

  def self.build_logger(opts)
    formatter_type = opts.delete(:formatter)
    customize_event = opts.delete(:customize_event)
    formatter = Formatter.new(formatter_type,
                              customize_event: customize_event,
                              error_logger: opts.fetch(:error_logger, LogStashLogger.configuration.default_error_logger))

    logger_type = opts[:type].to_s.to_sym
    logger = case logger_type
    when :multi_logger
      inherited = { formatter: formatter_type, customize_event: customize_event }.compact
      build_multi_logger(opts, inherited)
    when :syslog
      build_syslog_logger(opts)
    else
      build_default_logger(opts)
             end

    logger.formatter = formatter if formatter
    logger
  end


  def self.build_default_logger(opts)
    logger_class = opts.delete(:logger_class) || ::Logger
    device = Device.new(opts)
    logger_class.new(device).tap do |logger|
      logger.instance_variable_set(:@device, device)
      extend_logger(logger)
    end
  end

  # Each child logger gets the top-level options, including the top-level
  # formatter and customize_event; an output's own options win.
  def self.build_multi_logger(opts, inherited = {})
    output_configurations = opts.delete(:outputs) || []
    loggers = output_configurations.map do |config|
      logger_opts = inherited.merge(opts).merge(config)
      build_logger(logger_opts)
    end
    MultiLogger.new(loggers)
  end

  def self.build_syslog_logger(opts)
    logger = begin
      require 'syslog/logger'

      Syslog::Logger.new(opts[:program_name], opts[:facility])
    rescue ArgumentError
      Syslog::Logger.new(opts[:program_name])
    end

    extend_logger(logger)
  end

  def self.extend_logger(logger)
    logger.extend(self)
    logger.extend(TaggedLogging)
    logger.extend(SilencedLogging)
  end
end
