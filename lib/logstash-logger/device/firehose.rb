require 'aws-sdk'
require 'logstash-logger/device/aws_stream'

module LogStashLogger
  module Device
    class Firehose < Connectable
      include Device::AwsStream

      DEFAULT_REGION = 'us-east-1'
      DEFAULT_STREAM = 'logstash'
      RECOVERABLE_ERROR_CODES = [
        "ServiceUnavailable",
        "InternalFailure"
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
        @io = ::Aws::Firehose::Client.new(
          region: @aws_region,
          credentials: ::Aws::Credentials.new(@access_key_id, @secret_access_key)
        )
      end

      def write_batch(messages, group = nil)
        firehose_records = messages.map do |message|
          {
            data: message,
          }
        end

        with_connection do
          resp = @io.put_record_batch({
            records: firehose_records,
            delivery_stream_name: @stream
          })

          # Put any failed records back into the buffer
          if resp.failed_put_count != 0
            resp.request_responses.each_with_index do |record, index|
              if RECOVERABLE_ERROR_CODES.include?(record.error_code)
                log_warning("Failed to post record to firehose with error: #{record.error_code} #{record.error_message}")
                log_warning("Retrying")
                write(firehose_records[index][:data])
              elsif !record.error_code.nil? && record.error_code != ''
                log_error("Failed to post record to firehose with error: #{record.error_code} #{record.error_message}")
              end
            end
          end
        end
      end
    end
  end
end
