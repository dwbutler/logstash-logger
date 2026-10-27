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

describe LogStashLogger::Buffer, 'when the buffer is full' do
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
end
