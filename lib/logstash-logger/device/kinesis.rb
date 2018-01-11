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
        "ProvisionedThroughputExceededException"
      ].freeze

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
