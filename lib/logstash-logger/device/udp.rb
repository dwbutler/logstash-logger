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
      # Fields copied from an oversized record into its replacement. Logged
      # content can set any of them, so each is copied only when small.
      KEPT_FIELDS = %w[@timestamp @version severity host type].freeze
      KEPT_FIELD_LIMIT = 256
      # Records larger than this are not parsed to find the fields to copy.
      MAX_PARSED_BYTES = 1_048_576
      # The cee formatter writes "@cee:" before the JSON, and cee_syslog writes
      # "host progname:@cee:", where the progname can hold any character but a
      # control character. The replacement keeps such a header when the record
      # does not start with "{" and "@cee:{" appears within MAX_HEADER_BYTES.
      CEE_MARKER = '@cee:'
      MAX_HEADER_BYTES = 1024

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
      # is replaced by a small record that says so, so the collector still sees
      # that something was logged.
      def write_one(message)
        oversized = message.is_a?(String) && message.bytesize > max_datagram_size
        with_connection do
          send_datagram(message, oversized ? :replacement : :record)
        end
      end

      private

      # Sends the record, its replacement, or the replacement's notice alone,
      # moving to the next, smaller one each time the host rejects a datagram
      # as too large (its limit is below max_datagram_size).
      def send_datagram(message, form)
        @io.write(datagram(message, form))
      rescue Errno::EMSGSIZE => e
        log_error(e)
        smaller = { record: :replacement, replacement: :notice }[form]
        return log_warning("unrecoverable error, aborting write") unless smaller
        send_datagram(message, smaller)
      end

      def datagram(message, form)
        case form
        when :record then message
        when :replacement then replacement_record(message.to_s)
        else replacement_record(message.to_s, notice_only: true)
        end
      end

      def replacement_record(record, notice_only: false)
        size = record.bytesize
        log_warning("replacing a record of #{size} bytes that does not fit in one datagram (max_datagram_size: #{max_datagram_size})") unless notice_only
        notice = {
          'message' => "Record of #{size} bytes replaced: too large for one UDP datagram",
          'tags' => [RECORD_TOO_LARGE_TAG],
          'original_size' => size
        }
        header, body = split_header(record)
        line_end = record.end_with?("\n") ? "\n" : ''
        if "#{header}#{notice.to_json}#{line_end}".bytesize > max_datagram_size
          log_warning("leaving out the #{header.bytesize}-byte cee header: the replacement would be over max_datagram_size")
          header = ''
        end
        return "#{header}#{notice.to_json}#{line_end}" if notice_only
        replacement = "#{header}#{kept_fields(body).merge(notice).to_json}#{line_end}"
        # The kept fields can add about 1.5 KB; leave them out under a small limit.
        replacement = "#{header}#{notice.to_json}#{line_end}" if replacement.bytesize > max_datagram_size
        replacement
      end

      # Splits a cee or cee_syslog record into its header (through "@cee:")
      # and its JSON body. Other records have no header.
      def split_header(record)
        head = record.byteslice(0, MAX_HEADER_BYTES).b
        index = head.byteindex("#{CEE_MARKER}{") unless head.start_with?('{')
        return ['', record] unless index
        header_size = index + CEE_MARKER.bytesize
        return ['', record] if head.byteslice(0, header_size).match?(/[\x00-\x1f\x7f]/n)
        [record.byteslice(0, header_size), record.byteslice(header_size..)]
      end

      def kept_fields(body)
        return {} if body.bytesize > MAX_PARSED_BYTES
        original = (JSON.parse(body) rescue nil)
        return {} unless original.is_a?(Hash)
        KEPT_FIELDS.each_with_object({}) do |key, kept|
          value = original[key]
          kept[key] = value if !value.nil? && small_json?(value)
        end
      end

      # A parsed value may not serialize again, such as 1e400 (Infinity): the
      # json gem raises, and ActiveSupport writes null. Either way it is skipped.
      def small_json?(value)
        json = value.to_json
        json != 'null' && json.bytesize <= KEPT_FIELD_LIMIT
      rescue JSON::GeneratorError
        false
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
