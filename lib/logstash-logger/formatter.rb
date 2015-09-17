require 'logstash-logger/formatter/base'

module LogStashLogger
	module Formatter
		DEFAULT_FORMATTER = :json_lines

    autoload :LogStashEvent, 'logstash-logger/formatter/logstash_event'
    autoload :Json, 'logstash-logger/formatter/json'
    autoload :JsonLines, 'logstash-logger/formatter/json_lines'
    autoload :Cee, 'logstash-logger/formatter/cee'
    autoload :CeeSyslog, 'logstash-logger/formatter/cee_syslog'

		def self.new(formatter_type)
    	build_formatter(formatter_type)
    end

    def self.build_formatter(formatter_type)
      formatter_type ||= DEFAULT_FORMATTER

      formatter = if custom_formatter_instance?(formatter_type)
        formatter_type
      elsif custom_formatter_class?(formatter_type)
        formatter_type.new
      else
        formatter_klass(formatter_type).new
      end

      formatter.send(:extend, ::LogStashLogger::TaggedLogging::Formatter)
      formatter
    end

    def self.formatter_klass(formatter_type)
      case formatter_type.to_sym
      when :json_lines then JsonLines
      when :json then Json
      when :logstash_event then LogStashEvent
      when :cee then Cee
      when :cee_syslog then CeeSyslog
      else fail ArgumentError, 'Invalid formatter'
      end
    end

    def self.custom_formatter_instance?(formatter_type)
      formatter_type.respond_to?(:call)
    end

    def self.custom_formatter_class?(formatter_type)
      formatter_type.is_a?(Class) && formatter_type.method_defined?(:call)
    end
	end
end
