# frozen_string_literal: true

# Adapted from:
# https://github.com/rails/activerecord-session_store/blob/master/lib/active_record/session_store/extension/logger_silencer.rb
# https://github.com/rails/rails/pull/16885

require 'thread'

# Add support for Rails-style logger silencing. Thread-safe and no dependencies.
#
# Setup:
#   logger = Logger.new(STDOUT)
#   logger.extend(LogStashLogger::SilencedLogging)
#
# Usage:
#
#   logger.silence do
#     ...
#   end
#
module LogStashLogger
  module SilencedLogging
    def self.extended(logger)
      class << logger
        attr_accessor :silencer
        alias_method :level_without_thread_safety, :level
        alias_method :level, :level_with_thread_safety
        alias_method :add_without_thread_safety, :add
        alias_method :add, :add_with_thread_safety

        Logger::Severity.constants.each do |severity|
          instance_eval <<-EOT, __FILE__, __LINE__ + 1
            def #{severity.downcase}?                # def debug?
              Logger::#{severity} >= level           #   DEBUG >= level
            end                                      # end
          EOT
        end
      end

      logger.instance_eval do
        self.silencer = true
      end
    end

    def thread_level
      Thread.current[thread_hash_level_key]
    end

    def thread_level=(level)
      Thread.current[thread_hash_level_key] = level
    end

    def level_with_thread_safety
      thread_level || level_without_thread_safety
    end

    def add_with_thread_safety(severity, message = nil, progname = nil, &block)
      if (defined?(@logdev) && @logdev.nil?) || (severity || UNKNOWN) < level
        true
      else
        add_without_thread_safety(severity, message, progname, &block)
      end
    end

    # Silences the logger for the duration of the block.
    def silence(temporary_level = Logger::ERROR)
      if silencer
        begin
          self.thread_level = temporary_level
          yield self
        ensure
          self.thread_level = nil
        end
      else
        yield self
      end
    end

    private

    def thread_hash_level_key
      @thread_hash_level_key ||= :"ThreadSafeLogger##{object_id}@level"
    end
  end
end
