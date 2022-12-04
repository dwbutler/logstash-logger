# frozen_string_literal: true

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

      def initialize(opts)
        super
        @access_key_id = opts[:aws_access_key_id]
        @secret_access_key = opts[:aws_secret_access_key]
        @aws_region = opts[:aws_region]
        @stream = opts[:stream] || DEFAULT_STREAM
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
        connect unless connected?
        yield
      rescue => e
        log_error(e)
        log_warning('giving up')
        close(flush: false)
      end

      def write_batch(messages, group = nil)
        records = messages.map{ |m| transform_message(m) }

        with_connection do
          resp = put_records(records)

          # Put any failed records back into the buffer
          if !is_successful_response(resp)
            get_response_records(resp).each_with_index do |record, index|
              if self.class.recoverable_error_codes.include?(record.error_code)
                log_warning("Failed to post record using #{self.class.stream_class.name} with error: #{record.error_code} #{record.error_message}")
                log_warning('Retrying')
                write(records[index][:data])
              elsif !record.error_code.nil? && record.error_code != ''
                log_error("Failed to post record using #{self.class.stream_class.name} with error: #{record.error_code} #{record.error_message}")
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

