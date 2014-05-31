require 'logger'
require 'socket'
require 'time'

# Override the #to_s function to suit our needs
class LogStash::Event
  if RUBY_ENGINE == "jruby"
    public
    def to_s
      # Like SimpleFormatter from rails, when printing Event#to_s to print on console, terminate with \n
      return self.sprintf("%{+yyyy-MM-dd'T'HH:mm:ss.SSSZ} %{host} %{message}\n")
    end # def to_s
  else
    public
    def to_s
      # Like SimpleFormatter from rails, when printing Event#to_s to print on console, terminate with \n
      # Since we stringify @timestamp with LogStashLogger::Formatter#build_event, don't call Time.iso8601 again on what is now a string.
      return self.sprintf("#{self["@timestamp"]} %{host} %{message}\n")
    end # def to_s
  end
end

class LogStashLogger < ::Logger
  HOST = ::Socket.gethostname

  class Formatter < ::Logger::Formatter
    include ::LogStash::TaggedLogging::Formatter

    def call(severity, time, progname, message)
      event = build_event(message, severity, time)
      "#{event.to_json}\n"
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

      event['host'] ||= HOST

      current_tags.each do |tag|
        event.tag(tag)
      end

      # In case Time#to_json has been overridden - I can't find where this would be the case though....
      if event.timestamp.is_a?(Time)
        event.timestamp = event.timestamp.iso8601(3)
      end

      event
    end
  end
end
