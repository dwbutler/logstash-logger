class LogStashLogger < ::Logger
  
  HOST = ::Socket.gethostname
  
  def initialize(host, port, socket_type=:udp)
    super(::LogStashLogger::Socket.new(host, port, socket_type))
  end
  
  def add(severity, message = nil, progname = nil, &block)
    severity ||= UNKNOWN
    if severity < @level
      return true
    end
    progname ||= @progname
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    @logdev.write(
      format_message(format_severity(severity), Time.now, progname, message))
    true
  end
  
  def format_message(severity, time, progname, message)
    data = message
    if data.is_a?(String) && data[0] == '{'
      data = (JSON.parse(message) rescue nil) || message
    end
    
    event = case data
    when LogStash::Event
      data.clone
    when Hash
      event_data = data.merge("@timestamp" => time)
      LogStash::Event.new(event_data)
    when String
      LogStash::Event.new("message" => data, "@timestamp" => time)
    end
    
    event['severity'] ||= severity
    #event.type = progname

    event['source'] ||= HOST
    if event['source'] == 'unknown'
      event['source'] = HOST
    end
    
    event
  end
end
