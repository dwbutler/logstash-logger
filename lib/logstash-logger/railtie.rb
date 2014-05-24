require 'rails/railtie'

class LogStashLogger < ::Logger
  def self.setup(app)
    return unless app.config.logstash.present?

    fail ArgumentError, "Port is required" unless app.config.logstash.port
    app.config.logstash.host ||= "localhost"
    app.config.logstash.type ||= DEFAULT_CONNECTION_TYPE

    logger = LogStashLogger.new \
      app.config.logstash.host,
      app.config.logstash.port,
      app.config.logstash.type

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