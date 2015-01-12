require 'logger'
require 'logstash-logger/tagged_logging'

module LogStashLogger
  def self.new(*args)
    # devices_opts is array of device config hashses, i.e.
    # [
    #   {
    #     port: 5228,
    #     type: :tcp,
    #     host: 'localhost'
    #   },
    #   {
    #     type: :file,
    #     path: 'log/production.log'
    #   }
    # ]
    devices_opts = extract_opts(*args)

    devices = devices_opts.map do |device_opts|
      Device.new(device_opts)
    end

    device = if devices.many?
               MultiDelegator.delegate(:write, :close).to(*devices)
             else
               devices.first
             end

    ::Logger.new(device).tap do |logger|
      logger.instance_variable_set(:@device, device)
      logger.extend(self)
      logger.extend(TaggedLogging)
      logger.formatter = Formatter.new
    end
  end

  def self.extended(base)
    base.instance_eval do
      class << self
        attr_reader :device
      end

      def flush
        !!@device.flush
      end
    end
  end

  protected

  def self.extract_opts(*args)
    if args.length > 1
      # Args array
      args
    elsif Hash === args[0]
      # If hash provided, embed in array
      [args[0]]
    else
      fail ArgumentError, "Invalid LogStashLogger options"
    end
  end

end
