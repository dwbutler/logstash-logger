module LogStashLogger
  module Device
    class IO < Base
      def initialize(opts)
        super
        @io = opts[:io] || fail(ArgumentError, 'IO is required')
        @io.sync = sync unless sync.nil?
      end

      # The IO belongs to the caller, so reset leaves it open and writable.
      def reset
      end
    end
  end
end
