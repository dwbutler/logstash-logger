require 'json'

module LogStashLogger
  module Device
    class UDP < Socket
      # A formatted record too large for one UDP datagram. Builds the small
      # placeholder record the UDP device sends in its place, so the collector
      # still sees that something was logged.
      class OversizedRecord
        TAG = '_logstashlogger_record_too_large'
        # Fields copied from the record into its placeholder. Logged content can
        # set any of them, so each is copied only when small.
        KEPT_FIELDS = %w[@timestamp @version severity host type].freeze
        KEPT_FIELD_LIMIT = 256
        # Records larger than this are not parsed to find the fields to copy.
        MAX_PARSED_BYTES = 1_048_576
        # The cee formatter writes "@cee:" before the JSON, and cee_syslog writes
        # "host progname:@cee:", where the progname can hold any character but a
        # control character. The placeholder keeps such a header when the record
        # does not start with "{" and "@cee:{" appears within MAX_HEADER_BYTES.
        CEE_MARKER = '@cee:'
        MAX_HEADER_BYTES = 1024

        # record: the formatted record. max_datagram_size: the size the
        # placeholder should fit in. warn: called with a message when the
        # placeholder leaves out the record's header.
        def initialize(record, max_datagram_size, warn: ->(_message) {})
          @record = record.to_s
          @max_datagram_size = max_datagram_size
          @warn = warn
        end

        # The placeholder with the record's small identifying fields, or the
        # notice alone when those would put it over max_datagram_size.
        def placeholder
          full = frame(kept_fields.merge(notice))
          full.bytesize > @max_datagram_size ? notice_placeholder : full
        end

        # The placeholder without any copied fields.
        def notice_placeholder
          frame(notice)
        end

        private

        def notice
          size = @record.bytesize
          {
            'message' => "Record of #{size} bytes replaced: too large for one UDP datagram",
            'tags' => [TAG],
            'original_size' => size
          }
        end

        def frame(fields)
          "#{header}#{fields.to_json}#{line_end}"
        end

        def line_end
          @record.end_with?("\n") ? "\n" : ''
        end

        # The record's cee header, left out (with a warning) when it would put
        # even the notice over max_datagram_size.
        def header
          return @header if defined?(@header)
          @header = split_header.first
          if "#{@header}#{notice.to_json}#{line_end}".bytesize > @max_datagram_size
            @warn.call("leaving out the #{@header.bytesize}-byte cee header: the replacement would be over max_datagram_size")
            @header = ''
          end
          @header
        end

        # Splits a cee or cee_syslog record into its header (through "@cee:")
        # and its JSON body. Other records have no header.
        def split_header
          head = @record.byteslice(0, MAX_HEADER_BYTES).b
          index = head.byteindex("#{CEE_MARKER}{") unless head.start_with?('{')
          return ['', @record] unless index
          header_size = index + CEE_MARKER.bytesize
          return ['', @record] if head.byteslice(0, header_size).match?(/[\x00-\x1f\x7f]/n)
          [@record.byteslice(0, header_size), @record.byteslice(header_size..)]
        end

        def kept_fields
          body = split_header.last
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
      end
    end
  end
end
