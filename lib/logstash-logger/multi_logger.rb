# Adapted from https://github.com/ffmike/multilogger
module LogStashLogger
  class MultiLogger < ::Logger
    def level=(value)
      super
      @loggers.each do |logger|
        logger.level = value
      end
    end

    def progname=(value)
      super
      @loggers.each do |logger|
        logger.progname = value
      end
    end

    def datetime_format=(datetime_format)
      super
      @loggers.each do |logger|
        logger.datetime_format = datetime_format
      end
    end

    def formatter=(formatter)
      @loggers.each do |logger|
        logger.formatter ||= formatter
      end
    end

    # Array of Loggers to be logged to. These can be anything that acts reasonably like a Logger.
    attr_accessor :loggers

    # Any method not defined on standard Logger class, just send it on to anyone who will listen
    def method_missing(name, *args, &block)
      @loggers.each do |logger|
        if logger.respond_to?(name)
          logger.send(name, args, &block)
        end
      end
    end

    #
    # === Synopsis
    #
    #   MultiLogger.new([logger1, logger2])
    #
    # === Args
    #
    # +loggers+::
    #   An array of loggers. Each one gets every message that is sent to the MultiLogger instance
    #
    # === Description
    #
    # Create an instance.
    #
    def initialize(loggers)
      @loggers = []
      super(nil)
      @loggers = Array(loggers)
    end

    # Methods that write to logs just write to each contained logger in turn
    def add(severity, message = nil, progname = nil, &block)
      @loggers.each do |logger|
        logger.add(severity, message, progname, &block)
      end
    end

    def <<(msg)
      @loggers.each do |logger|
        logger << msg
      end
    end

    def debug(progname = nil, &block)
      @loggers.each do |logger|
        logger.debug(progname, &block)
      end
    end

    def info(progname = nil, &block)
      @loggers.each do |logger|
        logger.info(progname, &block)
      end
    end

    def warn(progname = nil, &block)
      @loggers.each do |logger|
        logger.warn(progname, &block)
      end
    end

    def error(progname = nil, &block)
      @loggers.each do |logger|
        logger.error(progname, &block)
      end
    end

    def fatal(progname = nil, &block)
      @loggers.each do |logger|
        logger.fatal(progname, &block)
      end
    end

    def unknown(progname = nil, &block)
      @loggers.each do |logger|
        logger.unknown(progname, &block)
      end
    end

    def close
      @loggers.each do |logger|
        logger.close if logger.respond_to?(:close)
      end
    end
  end
end
