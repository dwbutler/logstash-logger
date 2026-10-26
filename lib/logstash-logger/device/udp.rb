require 'json'

module LogStashLogger
  module Device
    class UDP < Socket
      # Largest payload of one IPv4 UDP datagram.
      MAX_DATAGRAM_SIZE = 65_507
      RECORD_TOO_LARGE_TAG = '_logstashlogger_record_too_large'

      def connect
        @io = UDPSocket.new.tap do |socket|
          socket.connect(@host, @port)
          socket.sync = sync unless sync.nil?
        end
      end

      # Each record is sent as one datagram. A record larger than a datagram
      # can hold is replaced by a small record that says so, so the collector
      # still sees that something was logged.
      def write_one(message)
        super(fit_datagram(message))
      end

      private

      def fit_datagram(message)
        return message unless message.is_a?(String) && message.bytesize > MAX_DATAGRAM_SIZE
        replacement_record(message)
      end

      def replacement_record(record)
        size = record.bytesize
        log_warning("replacing a record of #{size} bytes that does not fit in one datagram (#{MAX_DATAGRAM_SIZE} bytes)")
        notice = {
          'message' => "Record of #{size} bytes replaced: too large for one UDP datagram",
          'tags' => [RECORD_TOO_LARGE_TAG],
          'original_size' => size
        }
        "#{notice.to_json}#{"\n" if record.end_with?("\n")}"
      end
    end
  end
end
