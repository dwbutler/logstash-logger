require 'uri'
require 'net/http'

module LogStashLogger
  module Device

    # Rudimentary write to Logstash HTTP Input relying on buffering
    # rather than persistent HTTP connections for efficiency.
    class HTTP < Connectable

      # Request body formats, with the Content-Type sent by default for each.
      FORMATS = {
        json_array: "application/json",
        ndjson: "application/x-ndjson",
      }.freeze

      DEFAULT_FORMAT = :json_array

      def initialize(opts)
        super
        @url = URI(opts[:url])
        @format = (opts[:format] || DEFAULT_FORMAT).to_sym
        unless FORMATS.key?(@format)
          raise ArgumentError, "Unknown HTTP body format: #{@format.inspect} (expected one of #{FORMATS.keys.map(&:inspect).join(', ')})"
        end
        @content_type = opts[:content_type] || FORMATS[@format]
      end

      def connect
        # no-op
      end

      def write_one(message)
        write_batch([message])
      end

      def write_batch(messages, _group = nil)
        body = @format == :ndjson ? ndjson_body(messages) : json_array_body(messages)
        resp = Net::HTTP.post @url, body, {"Content-Type" => @content_type}
        raise resp.message if Net::HTTPError === resp
      end

      private

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
