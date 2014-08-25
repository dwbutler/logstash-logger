module LogStashLogger
  module Device
    class IO < Base
      def initialize(opts)
        super
        @io = opts[:io] || fail(ArgumentError, 'IO is required')
        @io.sync = sync unless sync.nil?
      end
    end
  end
end
