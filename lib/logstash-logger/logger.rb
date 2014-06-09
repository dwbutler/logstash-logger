require 'logger'
require 'logstash-logger/tagged_logging'

module LogStashLogger
  def self.new(*args)
    opts = extract_opts(*args)
    @device = Device.new(opts)

    ::Logger.new(@device).tap do |logger|
      logger.extend(self)
      logger.extend(TaggedLogging)
      logger.formatter = Formatter.new
    end
  end

  def self.included(base)
    base.instance_eval do
      attr_reader :device

      def flush
        !!@device.flush
      end
    end
  end

  protected

  def self.extract_opts(*args)
    if args.length > 1
      puts "[LogStashLogger] (host, port, type) constructor is deprecated. Please use an options hash instead."
      host, port, type = *args
      {host: host, port: port, type: type}
    elsif Hash === args[0]
      args[0]
    else
      fail ArgumentError, "Invalid LogStashLogger options"
    end
  end

end
