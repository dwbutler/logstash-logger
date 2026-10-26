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

      # Statuses that reject the content of the request. Sending the same
      # records again can never succeed, so the rejected records are found and
      # dropped. Every other error status is retried.
      CONTENT_REJECTED_STATUSES = [
        400, # Bad Request: the body is malformed
        413, # Content Too Large: the body is over the collector's size limit
        415, # Unsupported Media Type: the collector does not accept this content type
        422, # Unprocessable Content: the body is well-formed but cannot be processed
      ].freeze

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
        return if buffer_shutdown?
        messages = messages.map(&:to_s)
        resp = post(messages)
        return if resp.is_a?(Net::HTTPSuccess)
        raise upload_error(resp) unless content_rejected?(resp)
        deliver_one_at_a_time(messages, resp)
      end

      private

      def post(messages)
        body = @format == :ndjson ? ndjson_body(messages) : json_array_body(messages)
        Net::HTTP.post @url, body, {"Content-Type" => @content_type}
      end

      # The collector rejected the content of the batch. Send the records one
      # at a time and drop only the ones that are still rejected, so one bad
      # record does not hold back, or take down, the rest.
      def deliver_one_at_a_time(messages, batch_resp)
        return drop(messages.first, batch_resp) if messages.size == 1

        messages.each do |message|
          resp = post([message])
          next if resp.is_a?(Net::HTTPSuccess)

          if content_rejected?(resp)
            drop(message, resp)
          else
            raise upload_error(resp)
          end
        end
      end

      def content_rejected?(resp)
        CONTENT_REJECTED_STATUSES.include?(resp.code.to_i)
      end

      def drop(message, resp)
        log_warning("dropping a record of #{message.bytesize} bytes that the collector rejected: HTTP #{resp.code} #{resp.message}")
      end

      def upload_error(resp)
        RuntimeError.new("HTTP log upload failed: #{resp.code} #{resp.message}").tap { |e| log_error(e) }
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
