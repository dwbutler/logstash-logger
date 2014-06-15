require 'rails/railtie'

module LogStashLogger
  def self.setup(app)
    return unless app.config.logstash.present?

    logger_options = app.config.logstash

    if logger_options.type == :file
      logger_options.path ||= app.config.paths["log"].first
    end

    if app.config.respond_to?(:autoflush_log)
      logger_options.sync = app.config.autoflush_log
    end

    logger = LogStashLogger.new(logger_options)

    logger.level = ::Logger.const_get(app.config.log_level.to_s.upcase)

    app.config.logger = logger
  end

  class Railtie < ::Rails::Railtie
    config.logstash = ActiveSupport::OrderedOptions.new

    initializer :logstash_logger, before: :initialize_logger do |app|
      LogStashLogger.setup(app)
    end
  end
end
