require 'logger'
require 'stringio'

# A Connectable device that "sends" records into memory, so buffer behaviour
# can be tested without sockets. A gate can hold writes open, and connects can
# be made to fail.
class RecordingDevice < LogStashLogger::Device::Connectable
  attr_reader :lines, :connects, :error_log
  attr_accessor :fail_connect, :gate

  def initialize(opts = {})
    @lines = []
    @connects = 0
    @error_log = StringIO.new
    super({ buffer_flush_at_exit: false, error_logger: ::Logger.new(@error_log) }.merge(opts))
  end

  def connect
    @connects += 1
    raise Errno::ECONNREFUSED, 'collector down' if fail_connect
    @io = RecordingIO.new(self)
  end

  def state
    @buffer_state
  end

  def timer
    @flush_timer_thread
  end

  class RecordingIO
    def initialize(device)
      @device = device
    end

    def write(message)
      @device.gate&.call
      @device.lines << message
    end

    def flush; end
    def close; end
  end
end

# Polls until the block is true, giving up after `timeout` seconds. Flushes in
# these specs run on the buffer's background timer thread.
def wait_until(timeout: 5)
  deadline = Time.now + timeout
  sleep 0.02 until yield || Time.now > deadline
end
