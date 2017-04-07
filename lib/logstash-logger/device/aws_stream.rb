module LogStashLogger
  module Device
    # A simple module to abstract common methods for AWS Kinesis and Firehose
    module AwsStream

      def with_connection
        connect unless connected?
        yield
      rescue => e
        log_error(e)
        log_warning("giving up")
        close(flush: false)
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

