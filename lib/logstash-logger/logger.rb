class LogStashLogger < ::Logger
  
  HOST = ::Socket.gethostname
  
  def initialize(host, port, socket_type=:udp)
    super(::LogStashLogger::Socket.new(host, port, socket_type))
    self.formatter = Formatter.new
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

  class Formatter < ::Logger::Formatter
    def call(severity, time, progname, message)
      build_event(message, severity, time)
    end

    protected

    def build_event(message, severity, time)
      data = message
      if data.is_a?(String) && data.start_with?('{')
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

      # Support for ActiveSupport::TaggedLogging
      if respond_to?(:current_tags)
        current_tags.each do |tag|
          event.tag(tag)
        end
      end

      event
    end
  end
end
