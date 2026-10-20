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
        @ndjson = opts.fetch(:ndjson, false)
        @content_type = opts[:content_type] || default_content_type
      end

      def connect
        # no-op
      end

      def write_one(message)
        write_batch([message])
      end

      def write_batch(messages, _group = nil)
        body = @ndjson ? ndjson_body(messages) : json_array_body(messages)
        resp = Net::HTTP.post @url, body, {"Content-Type" => @content_type}
        raise resp.message if Net::HTTPError === resp
      end

      private

      def default_content_type
        @ndjson ? "application/x-ndjson" : "application/json"
      end

      # Logstash HTTP input expects a JSON array instead of lines of JSON
      def json_array_body(messages)
        "[#{messages.join(',')}]"
      end

      # Newline-delimited JSON: one event per line, each ending with a newline
      def ndjson_body(messages)
        messages.map { |m| m.end_with?("\n") ? m : "#{m}\n" }.join
      end

    end
  end
end
