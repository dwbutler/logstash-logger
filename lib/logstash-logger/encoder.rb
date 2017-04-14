module LogStashLogger
  module Encoder
    DEFAULT_ENCODER = :to_json

    autoload :JsonGenerate, 'logstash-logger/encoder/json_generate'
    autoload :ToJson, 'logstash-logger/encoder/to_json'

    def self.instance
      @instance ||= new(@global_encoder_type)
    end

    def self.global_encoder_type= (encoder_type)
      if @global_encoder_type != encoder_type
        @instance = nil
        @global_encoder_type = encoder_type
      end
    end

    def self.new(encoder_type)
      build_encoder(encoder_type)
    end

    def self.build_encoder(encoder_type)
      encoder_type ||= DEFAULT_ENCODER

      encoder = if custom_encoder_instance?(encoder_type)
        encoder_type
      elsif custom_encoder_class?(encoder_type)
        encoder_type.new
      else
        encoder_klass(encoder_type).new
      end

      encoder
    end

    def self.encoder_klass(encoder_type)
      case encoder_type.to_sym
      when :to_json then ToJson
      when :json_generate then JsonGenerate
      else fail ArgumentError, 'Invalid encoder'
      end
    end

    def self.custom_encoder_instance?(encoder_type)
      encoder_type.respond_to?(:call)
    end

    def self.custom_encoder_class?(encoder_type)
      encoder_type.is_a?(Class) && encoder_type.method_defined?(:call)
    end
  end
end
