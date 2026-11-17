module LogStashLogger
  module Device
    # Writes to a socket with a deadline, so a peer that stops reading cannot
    # hold the logging thread (sync mode) or the flush thread forever. Uses
    # write_nonblock and IO.select because JRuby does not apply IO#timeout to
    # writes.
    module WriteDeadline
      DEFAULT_WRITE_TIMEOUT = 5

      attr_reader :write_timeout

      private

      def write_to_io(message)
        return super unless @write_timeout
        data = message.to_s
        deadline = monotonic_now + @write_timeout
        until data.empty?
          case (written = @io.write_nonblock(data, exception: false))
          when :wait_writable then wait_for_socket(deadline, nil, [@io])
          # A TLS socket can need to read before it can write
          when :wait_readable then wait_for_socket(deadline, [@io], nil)
          else
            data = data.byteslice(written..-1)
            # Partial writes that keep succeeding are bounded too
            if !data.empty? && monotonic_now >= deadline
              raise ::IO::TimeoutError, "write timed out after #{@write_timeout} seconds"
            end
          end
        end
      end

      def wait_for_socket(deadline, read, write)
        remaining = deadline - monotonic_now
        return if remaining > 0 && ::IO.select(read, write, nil, remaining)
        raise ::IO::TimeoutError, "write timed out after #{@write_timeout} seconds"
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
