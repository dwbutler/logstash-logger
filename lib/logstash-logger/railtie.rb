require 'rails/railtie'

module LogStashLogger
  def self.setup(app)
    return unless app.config.logstash.present?

    logger_options = app.config.logstash

    sanitized_logger_options = if logger_options.is_a?(Array)
                                 logger_options.map do |opts|
                                   sanitize_logger_options(app, opts)
                                 end
                               else
                                 sanitize_logger_options(app, logger_options)
                               end

    logger = LogStashLogger.new(sanitized_logger_options)

    logger.level = ::Logger.const_get(app.config.log_level.to_s.upcase)

    app.config.logger = logger
  end

  def self.sanitize_logger_options(app, logger_options)
    # Convert logger options to OrderedOptions if regular Hash
    logger_options = ActiveSupport::OrderedOptions.new.merge(logger_options)

    if parsed_uri_options = LogStashLogger::Device.parse_uri_config(logger_options)
      logger_options.delete(:uri)
      logger_options.merge!(parsed_uri_options)
    end

    if logger_options.type == :file
      logger_options.path ||= app.config.paths["log"].first
    end

    if app.config.respond_to?(:autoflush_log)
      logger_options.sync = app.config.autoflush_log
    end

    logger_options
  end

  class Railtie < ::Rails::Railtie
    config.logstash = ActiveSupport::OrderedOptions.new

    initializer :logstash_logger, before: :initialize_logger do |app|
      LogStashLogger.setup(app)
    end
  end
end
