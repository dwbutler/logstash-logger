module LogStashLogger
  # Shamelessly copied from ActiveSupport::TaggedLogging
  module TaggedLogging
    def tagged(*tags)
      formatter.tagged(*tags) { yield self }
    end

    def flush
      formatter.clear_tags!
      super if defined?(super)
    end

    module Formatter
      def tagged(*tags)
        new_tags = push_tags(*tags)
        yield self
      ensure
        pop_tags(new_tags.size)
      end

      def push_tags(*tags)
        tags.flatten.reject(&:empty?).tap do |new_tags|
          current_tags.concat new_tags
        end
      end

      def pop_tags(size = 1)
        current_tags.pop size
      end

      def clear_tags!
        current_tags.clear
      end

      def current_tags
        Thread.current[:logstash_logger_tags] ||= []
      end
    end
  end
end
