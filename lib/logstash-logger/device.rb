require 'logstash-logger/device/base'

module LogStashLogger
  module Device
    DEFAULT_TYPE = :udp

    autoload :Base, 'logstash-logger/device/base'
    autoload :Connectable, 'logstash-logger/device/connectable'
    autoload :Socket, 'logstash-logger/device/socket'
    autoload :UDP, 'logstash-logger/device/udp'
    autoload :TCP, 'logstash-logger/device/tcp'
    autoload :Unix, 'logstash-logger/device/unix'
    autoload :Redis, 'logstash-logger/device/redis'
    autoload :Kafka, 'logstash-logger/device/kafka'
    autoload :File, 'logstash-logger/device/file'
    autoload :IO, 'logstash-logger/device/io'
    autoload :Stdout, 'logstash-logger/device/stdout'
    autoload :Stderr, 'logstash-logger/device/stderr'
    autoload :MultiDelegator, 'logstash-logger/device/multi_delegator'

    def self.new(opts)
      opts = opts.dup

      if opts.is_a?(Array)
        # Multiple device configs supplied... create a MultiDelegator
        devices = opts.map{|opt| build_device(opt)}
        Device::MultiDelegator.new(*devices)
      elsif Hash
        # Create a single device
        build_device(opts)
      else
        raise ArgumentError, "Invalid device options: must be a Hash or an Array of Hashes"
      end
    end

    def self.build_device(opts)
      if parsed_uri_opts = parse_uri_config(opts)
        opts = parsed_uri_opts
      end

      type = opts.delete(:type) || DEFAULT_TYPE

      device_klass_for(type).new(opts)
    end

    def self.parse_uri_config(opts)
      if uri = opts[:uri]
        parsed = ::URI.parse(uri)
        {type: parsed.scheme, host: parsed.host, port: parsed.port, path: parsed.path}
      end
    end

    def self.device_klass_for(type)
      case type.to_sym
        when :udp then UDP
        when :tcp then TCP
        when :unix then Unix
        when :file then File
        when :redis then Redis
        when :kafka then Kafka
        when :io then IO
        when :stdout then Stdout
        when :stderr then Stderr
        else fail ArgumentError, 'Invalid type'
      end
    end
  end
end
