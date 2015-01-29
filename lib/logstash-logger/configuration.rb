module LogStashLogger

  class Configuration
    attr_accessor :custom_fields

    def initialize(*args)
      @custom_fields = {}

      yield self if block_given?
      self
    end

  end
end
