require 'logger'

class LogStashLogger < ::Logger
  include ::LogStash::TaggedLogging

  attr_reader :connection

  def initialize(*args)
    connection_options = extract_connection_opts(*args)
    @connection = ::LogStash::Connection.new(connection_options)
    super(@connection)
    self.formatter = Formatter.new
  end

  def flush
    !!@connection.flush
  end

  protected

  def extract_connection_opts(*args)
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
