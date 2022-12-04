# frozen_string_literal: true

module LogStashLogger
  class << self
    def configure(&block)
      @configuration = Configuration.new(&block) if block_given? || @configuration.nil?
      @configuration
    end

    alias :configuration :configure
  end

  class Configuration
    attr_accessor :customize_event_block
    attr_accessor :max_message_size
    attr_accessor :default_error_logger

    def initialize(*args)
      @customize_event_block = nil
      @default_error_logger = Logger.new($stderr)

      yield self if block_given?
      self
    end

    def customize_event(&block)
      @customize_event_block = block
    end

  end
end
