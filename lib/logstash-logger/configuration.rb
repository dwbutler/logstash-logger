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

    def initialize(*args)
      @customize_event_block = nil

      yield self if block_given?
      self
    end

    def customize_event(&block)
      @customize_event_block = block
    end

  end
end
