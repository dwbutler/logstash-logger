require 'logstash-logger/device/udp/oversized_record'

module LogStashLogger
  module Device
    class UDP < Socket
      # Largest payload of one IPv4 UDP datagram, and the largest allowed value:
      # 65,535 (IPv4 packet) - 20 (IPv4 header) - 8 (UDP header). The device's
      # UDPSocket is IPv4. Hosts or collectors with a smaller limit (macOS
      # allows 9216 bytes by default) need a lower :max_datagram_size.
      DEFAULT_MAX_DATAGRAM_SIZE = 65_507
      MIN_MAX_DATAGRAM_SIZE = 512

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
      # max_datagram_size, or one the host rejects as too large for a datagram,
      # is replaced by a small placeholder record (see OversizedRecord), so the
      # collector still sees that something was logged.
      def write_one(message)
        oversized = message.is_a?(String) && message.bytesize > max_datagram_size
        with_connection do
          send_datagram(message, oversized ? :placeholder : :record)
        end
      end

      private

      # Sends the record, its placeholder, or the placeholder's notice alone,
      # moving to the next, smaller one each time the host rejects a datagram
      # as too large (its limit is below max_datagram_size).
      def send_datagram(message, form)
        @io.write(datagram(message, form))
      rescue Errno::EMSGSIZE => e
        log_error(e)
        smaller = { record: :placeholder, placeholder: :notice }[form]
        return log_warning("unrecoverable error, aborting write") unless smaller
        send_datagram(message, smaller)
      end

      def datagram(message, form)
        case form
        when :record then message
        when :placeholder
          log_warning("replacing a record of #{message.to_s.bytesize} bytes that does not fit in one datagram (max_datagram_size: #{max_datagram_size})")
          oversized_record(message).placeholder
        else oversized_record(message).notice_placeholder
        end
      end

      def oversized_record(message)
        OversizedRecord.new(message, max_datagram_size, warn: method(:log_warning))
      end

      def parse_max_datagram_size(value)
        bytes = Integer(value)
        return bytes if (MIN_MAX_DATAGRAM_SIZE..DEFAULT_MAX_DATAGRAM_SIZE).cover?(bytes)
        raise ArgumentError, "max_datagram_size must be #{MIN_MAX_DATAGRAM_SIZE}..#{DEFAULT_MAX_DATAGRAM_SIZE} bytes: #{value.inspect}"
      rescue TypeError
        raise ArgumentError, "max_datagram_size must be a number of bytes: #{value.inspect}"
      end
    end
  end
end
