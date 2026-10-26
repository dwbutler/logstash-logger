begin
  require 'aws-sdk-core'
rescue LoadError
  require 'aws-sdk'
end

module LogStashLogger
  module Device
    class AwsStream < Connectable

      DEFAULT_STREAM = 'logstash'

      @stream_class = nil
      @recoverable_error_codes = []

      class << self
        attr_accessor :stream_class, :recoverable_error_codes
      end

      attr_accessor :aws_region, :stream
      attr_reader :max_record_bytes

      def initialize(opts)
        super
        @access_key_id = opts[:aws_access_key_id]
        @secret_access_key = opts[:aws_secret_access_key]
        @aws_region = opts[:aws_region]
        @stream = opts[:stream] || DEFAULT_STREAM
        # The largest record the stream accepts. Kinesis streams can be
        # configured above the 1 MiB default, up to 10 MiB.
        @max_record_bytes = Integer(opts[:aws_max_record_bytes] || self.class.max_record_bytes)
      end

      # Service limits, defined by each subclass
      def self.max_records
        fail NotImplementedError
      end

      def self.max_record_bytes
        fail NotImplementedError
      end

      def self.max_request_bytes
        fail NotImplementedError
      end

      def transform_message(message)
        fail NotImplementedError
      end

      def put_records(records)
        fail NotImplementedError
      end

      def is_successful_response(resp)
        fail NotImplementedError
      end

      def get_response_records(resp)
        fail NotImplementedError
      end

      def connect
        client_opts = {}
        client_opts[:credentials] = Aws::Credentials.new(@access_key_id, @secret_access_key) unless @access_key_id == nil || @secret_access_key == nil
        client_opts[:region] = @aws_region unless @aws_region == nil
        @io = self.class.stream_class.new(client_opts)
      end

      def with_connection
        return if buffer_shutdown?
        connect unless connected?
        yield
      rescue => e
        log_error(e)
        disconnect
        raise
      end

      def write_batch(messages, _group = nil)
        records = []
        messages.each do |message|
          record = transform_message(message.to_s)
          size = record_size(record)
          if size > max_record_bytes
            log_warning("dropping a record of #{size} bytes: over the #{max_record_bytes}-byte limit of #{self.class.stream_class.name}")
          else
            records << record
          end
        end

        slices = request_slices(records)
        slices.each_with_index do |slice, index|
          begin
            with_connection { send_slice(slice) }
          rescue StandardError
            # Already logged by with_connection. Only records that were not
            # sent go back; dropped oversized records never do.
            unsent = slices[index..-1].flatten(1).map { |r| r[:data] }
            give_back(unsent)
            return
          end
        end
      end

      def write_one(message)
        write_batch([message])
      end

      def close!
        @io = nil
      end

      private

      # The AWS SDK keeps one pool of HTTPS connections for the whole process,
      # so a forked process inherits the parent's. Empty it, so this process
      # opens its own connections instead of sharing the parent's TLS
      # sessions. This closes the pooled sessions, so the parent's next request
      # may need one of the SDK's retries on a new connection. It runs on every
      # fork, also when this output holds no client: the pool can still hold
      # its connections.
      def release_inherited_connection(_client)
        # aws-sdk v2 has no CORE_GEM_VERSION, and no such bug
        if defined?(Aws::CORE_GEM_VERSION) && BROKEN_POOL_EMPTY.satisfied_by?(Gem::Version.new(Aws::CORE_GEM_VERSION))
          log_warning("aws-sdk-core #{Aws::CORE_GEM_VERSION} cannot empty its connection pool safely, " \
                      "so this forked process may share the parent's connections; upgrade to 3.196.1 or later")
          return
        end
        Aws.empty_connection_pools! if Aws.respond_to?(:empty_connection_pools!)
      end

      # In these releases ConnectionPool#empty! stops the pool from taking new
      # connections afterwards (fixed in 3.196.1).
      BROKEN_POOL_EMPTY = Gem::Requirement.new('>= 3.194.2', '< 3.196.1')

      def send_slice(records)
        resp = put_records(records)
        return if is_successful_response(resp)

        retries = []
        retry_codes = []
        get_response_records(resp).each_with_index do |record, index|
          if self.class.recoverable_error_codes.include?(record.error_code)
            retries << records[index][:data]
            retry_codes << record.error_code
          elsif !record.error_code.nil? && record.error_code != ''
            log_warning("dropping a record that #{self.class.stream_class.name} rejected: #{record.error_code} #{record.error_message}")
          end
        end
        return if retries.empty?

        log_warning("#{retries.size} records will be retried on the next flush (#{retry_codes.tally.map { |c, n| "#{c}: #{n}" }.join(', ')})")
        # This runs inside a flush, so requeue without the full-buffer check,
        # which would count the batch being flushed against the limit.
        buffer_requeue(retries, @buffer_group)
      end

      def record_size(record)
        record[:data].bytesize + record.fetch(:partition_key, '').bytesize
      end

      # Groups records into requests that fit the service's record-count and
      # request-size limits.
      def request_slices(records)
        slices = []
        bytes = 0
        records.each do |record|
          size = record_size(record)
          if slices.empty? || slices.last.size >= self.class.max_records || bytes + size > self.class.max_request_bytes
            slices << []
            bytes = 0
          end
          slices.last << record
          bytes += size
        end
        slices
      end

      # Records from a request that failed: retried on the next flush, or
      # dropped when drop_messages_on_flush_error is set.
      def give_back(messages)
        return if messages.empty?
        if @drop_messages_on_flush_error
          log_warning("dropping #{messages.size} records after a failed request")
        else
          log_warning("#{messages.size} records will be retried on the next flush")
          buffer_requeue(messages, @buffer_group)
        end
      end

    end
  end
end

