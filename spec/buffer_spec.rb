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
      wait_until { device.lines.include?('delivered') }

      expect(timer).to be_alive
      expect(device.state[:outgoing_count]).to eq(0)
      expect(device.lines).to eq(['delivered'])
    end
  end
end

describe LogStashLogger::Buffer, 'when the buffer is full' do
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
      (1..5).each { |i| device.write("queued-#{i}") }
      blocked.pop # the timer thread is now writing the first record
    end

    it 'drops only the new records and keeps the flush running' do
      timer = device.timer
      (1..7).each { |i| device.write("overflow-#{i}") }

      expect(timer).to be_alive
      device.gate = nil
      release << true
      wait_until { device.lines.size == 5 }
      device.write('after')
      device.buffer_flush(force: true)

      expect(device.lines).to eq((1..5).map { |i| "queued-#{i}" } + ['after'])
      expect(device.error_log.string.scan('Buffer Full').size).to eq(1)
      expect(device.error_log.string).to include('Dropped 7 records because the buffer was full')
    end
  end

  context 'with drop_messages_on_full_buffer: false' do
    it 'waits for room and reports it once' do
      device = RecordingDevice.new(buffer_max_items: 2, buffer_max_interval: 0.05, drop_messages_on_full_buffer: false)
      release = Queue.new
      blocked = Queue.new
      device.gate = -> { blocked << true; release.pop }
      device.write('a')
      device.write('b')
      blocked.pop

      writer = Thread.new { device.write('c') }
      sleep 0.5
      expect(writer).to be_alive
      expect(device.error_log.string.scan('Buffer Full').size).to eq(1)

      device.gate = nil
      release << true
      expect(writer.join(5)).not_to be_nil
      wait_until { device.lines.include?('c') }
      expect(device.lines).to eq(%w[a b c])
    end
  end
end

describe LogStashLogger::Device::Connectable, '#close' do
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
    device = RecordingDevice.new(buffer_max_interval: 0.05, buffer_flush_at_exit: true)
    closed = Queue.new
    device.gate = -> { device.gate = nil; device.close(flush: false); closed << Thread.current }
    device.write('a')
    timer = closed.pop
    timer.join(2)

    expect(timer).not_to be_alive
    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY[device]).to be(false)
  end

  it 'is registered for an exit-time flush until it is closed' do
    device = RecordingDevice.new(buffer_flush_at_exit: true)
    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY[device]).to be(true)
    device.close
    expect(LogStashLogger::Buffer::AT_EXIT_REGISTRY[device]).to be(false)
  end

  it 'keeps buffering after a failed write, which only drops the connection' do
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

  it 'leaves #reset usable on an open device' do
    device = RecordingDevice.new(buffer_max_interval: 0.05)
    device.reset
    device.write('after reset')
    wait_until { device.lines.include?('after reset') }
    expect(device.timer).to be_alive
  end
end

describe 'outputs with their own connection handling' do
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
