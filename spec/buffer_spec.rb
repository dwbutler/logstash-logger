require 'logstash-logger'
require_relative 'support/recording_device'

describe LogStashLogger::Buffer do
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
