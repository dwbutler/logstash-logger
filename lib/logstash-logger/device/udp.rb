require 'json'

module LogStashLogger
  module Device
    class UDP < Socket
      # Largest payload of one IPv4 UDP datagram. Hosts or collectors with a
      # smaller limit (macOS allows 9216 bytes by default) need a lower
      # :max_datagram_size.
      DEFAULT_MAX_DATAGRAM_SIZE = 65_507
      MIN_MAX_DATAGRAM_SIZE = 512
      RECORD_TOO_LARGE_TAG = '_logstashlogger_record_too_large'

      attr_reader :max_datagram_size

      # The option is checked before super, which starts the buffer's flush
      # timer and at_exit hook, so an invalid value leaves nothing running.
      def initialize(opts)
        @max_datagram_size = parse_max_datagram_size(opts.fetch(:max_datagram_size, DEFAULT_MAX_DATAGRAM_SIZE))
        super
      end

      def connect
        @io = UDPSocket.new.tap do |socket|
          socket.connect(@host, @port)
          socket.sync = sync unless sync.nil?
        end
      end

      # Each record is sent as one datagram. A record larger than
      # max_datagram_size is replaced by a small record that says so, so the
      # collector still sees that something was logged.
      def write_one(message)
        super(fit_datagram(message))
      end

      private

      def fit_datagram(message)
        return message unless message.is_a?(String) && message.bytesize > max_datagram_size
        replacement_record(message)
      end

      def replacement_record(record)
        size = record.bytesize
        log_warning("replacing a record of #{size} bytes that does not fit in one datagram (max_datagram_size: #{max_datagram_size})")
        notice = {
          'message' => "Record of #{size} bytes replaced: too large for one UDP datagram",
          'tags' => [RECORD_TOO_LARGE_TAG],
          'original_size' => size
        }
        "#{notice.to_json}#{"\n" if record.end_with?("\n")}"
      end

      def parse_max_datagram_size(value)
        bytes = Integer(value)
        return bytes if bytes >= MIN_MAX_DATAGRAM_SIZE
        raise ArgumentError, "max_datagram_size must be at least #{MIN_MAX_DATAGRAM_SIZE} bytes: #{value.inspect}"
      rescue TypeError
        raise ArgumentError, "max_datagram_size must be a number of bytes: #{value.inspect}"
      end
    end
  end
end
