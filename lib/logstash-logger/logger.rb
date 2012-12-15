class LogStashLogger < ::Logger
  
  attr_reader :client
  
  LOGSTASH_EVENT_FIELDS = %w(@timestamp @tags @type @source @fields @message).freeze
  HOST = Socket.gethostname
  
  def initialize(host, port)
    @client = ::LogStashLogger::TCPClient.new(host, port)
    super
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
    @client.write(
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
      event_data = {
        "@tags" => [],
        "@fields" => {},
        "@timestamp" => time
      }
      LOGSTASH_EVENT_FIELDS.each do |field_name|
        if field_data = data.delete(field_name)
          event_data[field_name] = field_data
        end
      end
      event_data["@fields"].merge!(data)
      LogStash::Event.new(event_data)
    when String
      LogStash::Event.new("@message" => data, "@timestamp" => time)
    end
    
    event['severity'] ||= severity
    #event.type = progname
    if event.source == 'unknown'
      event["@source"] = HOST
      event["@source_host"] = HOST
    end
    
    event
  end
end