require 'logstash-logger'
require_relative 'support/recording_device'

describe LogStashLogger::Buffer do
  describe 'accounting when the buffer is reset during a flush' do
    it 'keeps outgoing_count at zero after the in-flight flush finishes' do
      device = RecordingDevice.new(buffer_max_interval: 3600)
      release = Queue.new
      blocked = Queue.new
      device.gate = -> { blocked << true; release.pop }
      3.times { |i| device.write("r#{i}") }

      flusher = Thread.new { device.buffer_flush(force: true) }
      blocked.pop
      device.reset
      device.gate = nil
      release << true
      flusher.join(5)

      expect(device.state[:outgoing_count]).to eq(0)
      expect(device.state[:pending_count]).to eq(0)
    end
  end

  describe 'a final flush that waits behind another flush' do
    it 'flushes records written after a reset while it waited' do
      device = RecordingDevice.new(buffer_max_interval: 3600)
      release = Queue.new
      blocked = Queue.new
      device.gate = -> { blocked << true; release.pop }
      device.write('first')
      flusher = Thread.new { device.buffer_flush(force: true) }
      blocked.pop

      final = Thread.new { device.buffer_flush(final: true) }
      wait_until { final.status == 'sleep' }
      device.reset
      device.write('after reset')
      device.gate = nil
      release << true
      flusher.join(5)
      final.join(5)

      expect(device.lines).to eq(['first', 'after reset'])
    end
  end

  describe 'drop_messages_on_flush_error' do
    it 'keeps the timer running after a failed timed flush' do
      device = RecordingDevice.new(buffer_max_interval: 0.1, drop_messages_on_flush_error: true)
      device.fail_connect = true
      state_before = device.state
      device.write('dropped')
      # The failed flush resets the buffer (dropping 'dropped'); wait for that
      # reset so the next record is not written into the state being discarded.
      wait_until { !device.state.equal?(state_before) }
      timer = device.timer

      device.fail_connect = false
      device.write('delivered')
      # The record is written before the flush updates its counts
      wait_until { device.lines.include?('delivered') && device.state[:outgoing_count] == 0 }

      expect(timer).to be_alive
      expect(device.state[:outgoing_count]).to eq(0)
      expect(device.lines).to eq(['delivered'])
    end
  end
end

# Puts every record back to retry, as the AWS outputs do when throttled.
class RequeueingDevice < RecordingDevice
  attr_reader :attempts

  def write_batch(messages, group = nil)
    @attempts = (@attempts || 0) + 1
    buffer_requeue(messages, group)
  end
end

# Puts back the records of one group, as an output does for a throttled request.
class GroupRequeueingDevice < RecordingDevice
  def write_batch(messages, group = nil)
    return buffer_requeue(messages, group) if group == 'throttled'
    super
  end
end

describe LogStashLogger::Buffer, 'when the buffer is full' do
  it 'keeps a requeue in one group as a failure when a later group succeeds' do
    device = GroupRequeueingDevice.new(buffer_max_interval: 3600)
    device.buffer_receive('a', 'throttled')
    device.buffer_receive('b', 'ok')
    device.buffer_flush(force: true)

    expect(device.state[:last_flush_error]).not_to be_nil
  end

  it 'waits buffer_max_interval between retries when the output puts records back' do
    device = RequeueingDevice.new(buffer_max_items: 1, buffer_max_interval: 0.5, drop_messages_on_full_buffer: false)
    writer = Thread.new { 2.times { |i| device.write("r#{i}") } }
    sleep 1.2
    writer.kill
    writer.join(1)

    # One attempt when the buffer fills, the timer's, and the blocked
    # writer's every buffer_max_interval; not one every 0.1 seconds.
    expect(device.attempts).to be_between(1, 6)
  end

  it 'flushes from the log call that reaches buffer_max_items' do
    device = RecordingDevice.new(buffer_max_items: 3, buffer_max_interval: 3600)
    %w[r1 r2 r3].each { |r| device.write(r) }

    expect(device.lines).to eq(%w[r1 r2 r3])
  end

  it 'flushes a burst larger than buffer_max_items instead of discarding it' do
    device = RecordingDevice.new(buffer_max_items: 50, buffer_max_interval: 3600)
    records = (1..60).map { |i| "r#{i}" }
    records.each { |r| device.write(r) }
    device.buffer_flush(force: true)

    expect(device.lines).to eq(records)
    expect(device.error_log.string).not_to include('Buffer Full')
  end

  context 'while a flush is still in progress' do
    let(:device) { RecordingDevice.new(buffer_max_items: 5, buffer_max_interval: 0.05) }
    let(:release) { Queue.new }
    let(:blocked) { Queue.new }

    before do
      device.gate = -> { blocked << true; release.pop }
      # The write that fills the buffer may flush it itself, so write from
      # another thread
      @writer = Thread.new { (1..5).each { |i| device.write("queued-#{i}") } }
      blocked.pop # a flush (the timer's or that write's) is now writing the first record
    end

    after do
      device.gate = nil
      release << true
      @writer.join(5)
    end

    it 'drops only the new records and keeps the flush running' do
      timer = device.timer
      (1..7).each { |i| device.write("overflow-#{i}") }

      expect(timer).to be_alive
      device.gate = nil
      release << true
      wait_until { device.lines.size == 5 }
      device.write('after')
      # The timer's flush can still hold the flush lock after writing its
      # last record; a final flush waits for it instead of skipping.
      device.buffer_flush(final: true)

      expect(device.lines).to eq((1..5).map { |i| "queued-#{i}" } + ['after'])
    end

    it 'reports the full buffer once, then how many records were dropped' do
      (1..7).each { |i| device.write("overflow-#{i}") }
      device.gate = nil
      release << true
      wait_until { device.lines.size == 5 }
      device.write('after')

      expect(device.error_log.string.scan('Buffer Full').size).to eq(1)
      expect(device.error_log.string).to include('Dropped 7 records because the buffer was full')
    end
  end

  it 'reports the dropped records when a flush makes room, without another log call' do
    device = RecordingDevice.new(buffer_max_items: 1, buffer_max_interval: 3600)
    device.fail_connect = true
    device.write('kept')
    device.write('dropped')
    expect(device.error_log.string).not_to include('Dropped')

    device.fail_connect = false
    device.buffer_flush(force: true)
    expect(device.error_log.string).to include('Dropped 1 records')
  end

  it 'reports the dropped records before a reset discards the buffer' do
    device = RecordingDevice.new(buffer_max_items: 1, buffer_max_interval: 3600)
    device.fail_connect = true
    device.write('kept')
    device.write('dropped')
    device.reset

    expect(device.error_log.string).to include('Dropped 1 records')
  end

  context 'with drop_messages_on_full_buffer: false' do
    it 'waits for room and reports it once' do
      device = RecordingDevice.new(buffer_max_items: 2, buffer_max_interval: 0.05, drop_messages_on_full_buffer: false)
      release = Queue.new
      blocked = Queue.new
      device.gate = -> { blocked << true; release.pop }
      # The write that fills the buffer may flush it itself, so write from
      # another thread
      filler = Thread.new { device.write('a'); device.write('b') }
      blocked.pop

      writer = Thread.new { device.write('c') }
      sleep 0.5
      expect(writer).to be_alive
      expect(device.error_log.string.scan('Buffer Full').size).to eq(1)

      device.gate = nil
      release << true
      expect(writer.join(5)).not_to be_nil
      filler.join(5)
      wait_until { device.lines.include?('c') }
      expect(device.lines).to eq(%w[a b c])
    end
  end
end

describe 'recovering from a failed write' do
  it 'keeps buffering, and reconnects on the next flush' do
    device = RecordingDevice.new(buffer_max_interval: 0.05)
    device.fail_connect = true
    device.write('first')
    wait_until { device.connects >= 1 }
    timer = device.timer
    device.fail_connect = false
    wait_until { device.lines.include?('first') }

    expect(timer).to be_alive
    expect(device.lines).to eq(['first'])
  end

  it 'leaves #reset usable' do
    device = RecordingDevice.new(buffer_max_interval: 0.05)
    device.reset
    device.write('after reset')
    wait_until { device.lines.include?('after reset') }
    expect(device.timer).to be_alive
  end

  it 'keeps the Redis flush timer running after a transient error' do
    redis = double('redis')
    calls = 0
    allow(redis).to receive(:rpush) { calls += 1; raise ::Redis::CannotConnectError, 'down' if calls == 1 }
    allow(redis).to receive(:quit)
    allow(::Redis).to receive(:new).and_return(redis)
    device = LogStashLogger::Device.new(type: :redis, buffer_max_interval: 0.05, buffer_flush_at_exit: false,
                                        error_logger: ::Logger.new(StringIO.new))
    timer = device.instance_variable_get(:@flush_timer_thread)
    device.write('a')
    wait_until { calls >= 2 }

    expect(timer).to be_alive
    expect(calls).to be >= 2
  end

  it 'keeps the Kinesis flush timer running after a transient error' do
    client = double('kinesis')
    calls = 0
    allow(client).to receive(:put_records) do |params|
      calls += 1
      raise Seahorse::Client::NetworkingError.new(StandardError.new('reset')) if calls == 1
      Aws::Kinesis::Types::PutRecordsOutput.new(failed_record_count: 0, records: params[:records].map { Aws::Kinesis::Types::PutRecordsResultEntry.new })
    end
    allow(Aws::Kinesis::Client).to receive(:new).and_return(client)
    device = LogStashLogger::Device.new(type: :kinesis, aws_region: 'us-east-1', buffer_max_interval: 0.05,
                                        buffer_flush_at_exit: false, error_logger: ::Logger.new(StringIO.new))
    timer = device.instance_variable_get(:@flush_timer_thread)
    device.write('a')
    wait_until { calls >= 2 }

    expect(timer).to be_alive
    expect(calls).to be >= 2
  end
end

describe LogStashLogger::Device::Connectable, '#close' do
  it 'drops a batch whose flush fails after the device was closed' do
    device = RecordingDevice.new(buffer_max_interval: 3600)
    release = Queue.new
    blocked = Queue.new
    device.gate = -> { blocked << true; release.pop; raise IOError, 'closed stream' }
    device.write('a')
    flusher = Thread.new { device.buffer_flush(force: true) }
    blocked.pop
    device.close(flush: false)
    release << true
    flusher.join(5)

    expect(device.state[:pending_count]).to eq(0)
    expect(device.state[:outgoing_count]).to eq(0)
  end

  it 'shuts down even when the final flush raises' do
    hook_raises = Class.new(RecordingDevice) do
      def on_flush_error(_e)
        raise 'hook failed'
      end
    end
    device = hook_raises.new(buffer_max_interval: 3600)
    device.fail_connect = true
    device.write('a')

    expect { device.close }.not_to raise_error
    expect(device).to be_buffer_shutdown
    expect(device.timer).to be_nil
  end

  it 'releases a log call blocked on a full buffer' do
    device = RecordingDevice.new(buffer_max_items: 1, buffer_max_interval: 3600, drop_messages_on_full_buffer: false)
    device.fail_connect = true
    device.write('a')
    writer = Thread.new { device.write('b') }
    wait_until { writer.status == 'sleep' }
    device.close

    expect(writer.join(2)).to be_truthy
  end

  it 'drops the records the final flush could not send' do
    device = RecordingDevice.new(buffer_max_interval: 3600)
    device.fail_connect = true
    device.write('a')
    device.close

    expect(device.state[:pending_count]).to eq(0)
  end

  it 'ignores direct write_batch calls afterwards' do
    device = RecordingDevice.new(buffer_max_interval: 3600)
    device.close
    connects = device.connects
    device.write_batch(['direct'])

    expect(device.lines).to be_empty
    expect(device.connects).to eq(connects)
  end

  it 'stops the flush timer of every closed device' do
    devices = Array.new(10) { RecordingDevice.new(buffer_max_interval: 3600) }
    timers = devices.map(&:timer)
    devices.each(&:close)
    timers.each { |t| t.join(2) }
    expect(timers).to all(satisfy { |t| !t.alive? })
  end

  it 'flushes pending records, then ignores later writes without reconnecting' do
    device = RecordingDevice.new(buffer_max_interval: 3600, buffer_max_items: 3)
    device.write('before')
    device.close
    connects = device.connects

    5.times { |i| device.write("after-#{i}") }
    device.buffer_flush(force: true)
    expect(device.lines).to eq(['before'])
    expect(device.connects).to eq(connects)
    expect(device.timer).to be_nil
  end

  it 'does not reconnect to send records left over from a failed final flush' do
    device = RecordingDevice.new(buffer_max_interval: 3600)
    device.fail_connect = true
    device.write('left over')
    device.close
    device.fail_connect = false

    device.flush
    expect(device.to_io).to be_nil
    expect(device.lines).to be_empty
  end

  it 'completes when called from inside a timed flush' do
    device = RecordingDevice.new(buffer_max_interval: 0.05)
    closed = Queue.new
    device.gate = -> { device.gate = nil; device.close(flush: false); closed << Thread.current }
    device.write('a')
    timer = closed.pop
    timer.join(2)

    expect(timer).not_to be_alive
    expect(device.timer).to be_nil
  end
end

describe LogStashLogger::Buffer, 'exit-time flush' do
  it 'registers a device until it is closed' do
    device = RecordingDevice.new(buffer_flush_at_exit: true)
    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY[device]).to be(true)
    device.close
    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY[device]).to be(false)
  end

  it 'unregisters a device closed from inside a timed flush' do
    device = RecordingDevice.new(buffer_max_interval: 0.05, buffer_flush_at_exit: true)
    closed = Queue.new
    device.gate = -> { device.gate = nil; device.close(flush: false); closed << true }
    device.write('a')
    closed.pop

    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY[device]).to be(false)
  end

  it 'does not register a device when buffer_flush_at_exit is false' do
    device = RecordingDevice.new(buffer_flush_at_exit: false)
    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY.key?(device)).to be(false)
  end
end
