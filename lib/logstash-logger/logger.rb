require 'logger'

class LogStashLogger < ::Logger
  DEFAULT_CONNECTION_TYPE = :udp

  attr_reader :connection

  def initialize(host, port, type = DEFAULT_CONNECTION_TYPE)
    @connection = ::LogStash::Connection.new(host, port, type)
    super(@connection)
    self.formatter = Formatter.new
  end

  def flush
    !!@connection.flush
  end

  include ::LogStash::TaggedLogging
end
