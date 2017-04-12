require 'aws-sdk'

module LogStashLogger
  module Device
    class AwsStream < Connectable

      DEFAULT_REGION = 'us-east-1'
      DEFAULT_STREAM = 'logstash'

      attr_accessor :aws_region, :stream, :stream_class, :recoverable_error_codes

      def initialize(opts)
        super
        @access_key_id = opts[:aws_access_key_id] || ENV['AWS_ACCESS_KEY_ID']
        @secret_access_key = opts[:aws_secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY']
        @aws_region = opts[:aws_region] || DEFAULT_REGION
        @stream = opts[:stream] || DEFAULT_STREAM
        @stream_class = nil
        @recoverable_error_codes = []
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
        @io = @stream_class.new(
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
        close(flush: false)
      end

      def write_batch(messages, group = nil)
        records = messages.map{ |m| transform_message(m) }

        with_connection do
          resp = put_records(records)

          # Put any failed records back into the buffer
          if !is_successful_response(resp)
            get_response_records(resp).each_with_index do |record, index|
              if @recoverable_error_codes.include?(record.error_code)
                log_warning("Failed to post record using #{@stream_class.name} with error: #{record.error_code} #{record.error_message}")
                log_warning("Retrying")
                write(records[index][:data])
              elsif !record.error_code.nil? && record.error_code != ''
                log_error("Failed to post record using #{@stream_class.name} with error: #{record.error_code} #{record.error_message}")
              end
            end
          end
        end
      end

      def write_one(message)
        write_batch([message])
      end

      def close!
        @io = nil
      end

    end
  end
end

