require 'aws-sdk'
require 'logstash-logger/device/aws_stream'

module LogStashLogger
  module Device
    class Kinesis < AwsStream
      KINESIS_ERROR_CODES = [
        "ServiceUnavailable",
        "Throttling",
        "RequestExpired",
        "ProvisionedThroughputExceededException"
      ].freeze

      def initialize(opts)
        super
        @stream_class = ::Aws::Kinesis::Client
        @recoverable_error_codes = KINESIS_ERROR_CODES
      end

      def transform_message(message)
        {
          data: message,
          partition_key: SecureRandom.uuid
        }
      end

      def put_records(records)
        @io.put_records({
          records: records,
          stream_name: @stream
        })
      end

      def is_successful_response(resp)
        resp.failed_record_count == 0
      end

      def get_response_records(resp)
        resp.records
      end

    end
  end
end
