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
          when :wait_writable then wait_for_socket(deadline, :write, "write", @write_timeout)
          # A TLS socket can need to read before it can write
          when :wait_readable then wait_for_socket(deadline, :read, "write", @write_timeout)
          else
            data = data.byteslice(written..-1)
            # Partial writes that keep succeeding are bounded too
            if !data.empty? && monotonic_now >= deadline
              raise ::IO::TimeoutError, "write timed out after #{@write_timeout} seconds"
            end
          end
        end
      end

      def wait_for_socket(deadline, direction, operation, timeout)
        remaining = deadline - monotonic_now
        if remaining > 0
          ready = direction == :read ? ::IO.select([@io], nil, nil, remaining) : ::IO.select(nil, [@io], nil, remaining)
          return if ready
        end
        raise ::IO::TimeoutError, "#{operation} timed out after #{timeout} seconds"
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
