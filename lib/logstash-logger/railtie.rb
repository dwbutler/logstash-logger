require 'rails/railtie'

module LogStashLogger
  def self.setup(app)
    return unless app.config.logstash.present?

    logger_options = app.config.logstash

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
