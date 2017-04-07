require 'aws-sdk'
require 'logstash-logger/device/aws_stream'

module LogStashLogger
  module Device
    class Firehose < AwsStream

      def initialize(opts)
        super
        @stream_class = ::Aws::Firehose::Client
        @recoverable_error_codes = [
          "ServiceUnavailable",
          "InternalFailure",
          "ServiceUnavailableException"
        ].freeze
      end

      def transform_message(message)
        {
          data: message
        }
      end

      def put_records(records)
        @io.put_record_batch({
          records: records,
          delivery_stream_name: @stream
        })
      end

      def is_successful_response(resp)
        resp.failed_put_count == 0
      end

      def get_response_records(resp)
        resp.request_responses
      end

    end
  end
end
