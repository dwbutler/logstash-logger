begin
  require 'aws-sdk-firehose'
rescue LoadError
  require 'aws-sdk'
end

require 'logstash-logger/device/aws_stream'

module LogStashLogger
  module Device
    class Firehose < AwsStream
      @stream_class = ::Aws::Firehose::Client
      @recoverable_error_codes = [
        "ServiceUnavailable",
        "InternalFailure",
        "ServiceUnavailableException"
      ].freeze

      # https://docs.aws.amazon.com/firehose/latest/APIReference/API_PutRecordBatch.html
      # 1,000 KiB per record and 4 MB per request; these cannot be changed.
      def self.max_records; 500; end
      def self.max_record_bytes; 1_024_000; end
      def self.max_request_bytes; 4_000_000; end

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
