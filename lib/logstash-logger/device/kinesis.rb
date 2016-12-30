require 'aws-sdk'

module LogStashLogger
  module Device
    class Kinesis < Connectable

      DEFAULT_REGION = 'us-east-1'
      DEFAULT_STREAM = 'logstash'
      RECOVERABLE_ERROR_CODES = [
        "ServiceUnavailable",
        "Throttling",
        "RequestExpired",
        "ProvisionedThroughputExceededException"
      ]

      attr_accessor :aws_region, :stream

      def initialize(opts)
        super
        @access_key_id = opts[:aws_access_key_id] || ENV['AWS_ACCESS_KEY_ID']
        @secret_access_key = opts[:aws_secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY']
        @aws_region = opts[:aws_region] || DEFAULT_REGION
        @stream = opts[:stream] || DEFAULT_STREAM
      end

      def connect
        @io = ::Aws::Kinesis::Client.new(
          region: @aws_region,
          credentials: ::Aws::Credentials.new(@access_key_id, @secret_access_key)
        )
      end

      def with_connection
        connect unless connected?
        yield
      rescue => e
        log_error(e)
        log_warning("giving up")
      end

      def write_batch(messages, group = nil)
        kinesis_records = messages.map do |message|
          {
            data: message,
            partition_key: SecureRandom.uuid
          }
        end

        with_connection do
          resp = @io.put_records({
            records: kinesis_records,
            stream_name: @stream
          })

          # Put any failed records back into the buffer
          if resp.failed_record_count != 0
            resp.records.each_with_index do |record, index|
              if RECOVERABLE_ERROR_CODES.include?(record.error_code)
                log_warning("Failed to post record to kinesis with error: #{record.error_code} #{record.error_message}")
                log_warning("Retrying")
                write(kinesis_records[index][:data])
              elsif !record.error_code.nil? && record.error_code != ''
                log_error("Failed to post record to kinesis with error: #{record.error_code} #{record.error_message}")
              end
            end
          end
        end
      end

      def write_one(message)
        write_batch([message])
      end
    end
  end
end
