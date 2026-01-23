require 'uri'
require 'net/http'

module LogStashLogger
  module Device

    # Rudimentary write to Logstash HTTP Input relying on buffering
    # rather than persistent HTTP connections for efficiency.
    class HTTP < Connectable

      def initialize(opts)
        super
        @url = URI(opts[:url])
      end

      def connect
        # no-op
      end

      def write_one(message)
        write_batch([message])
      end

      def write_batch(messages, group = nil)
        # Logstash HTTP input expects JSON array instead of lines of JSON
        body = "[#{messages.join(',')}]"
        resp = Net::HTTP.post @url, body, {"Content-Type" => "application/json"}
        raise resp.message if Net::HTTPError === resp
      end

    end
  end
end
