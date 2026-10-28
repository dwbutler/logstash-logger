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
  end
end
