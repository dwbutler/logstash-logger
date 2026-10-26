begin
  require 'aws-sdk-kinesis'
rescue LoadError
  require 'aws-sdk'
end

require 'logstash-logger/device/aws_stream'

module LogStashLogger
  module Device
    class Kinesis < AwsStream
      @stream_class = ::Aws::Kinesis::Client
      @recoverable_error_codes = [
        "ServiceUnavailable",
        "Throttling",
        "RequestExpired",
        "ProvisionedThroughputExceededException",
        "InternalFailure"
      ].freeze

      # https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html
      # Records count the partition key. 1 MiB is the default and smallest
      # per-stream maximum; raise it with aws_max_record_bytes if the stream
      # is configured for larger records.
      def self.max_records; 500; end
      def self.max_record_bytes; 1_048_576; end
      def self.max_request_bytes; 10_485_760; end

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
