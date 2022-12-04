# frozen_string_literal: true

require 'logstash-logger'

describe LogStashLogger::Device::MultiDelegator do
  include_context 'device'

  # Create a MultiDelegator writing to both STDOUT and a StringIO
  subject { multi_delegator_device }

  it 'writes to all outputs' do
    expect($stdout).to receive(:write).once
    expect(io).to receive(:write).once

    subject.write('test')
  end

  describe '.new' do
    it 'merges top level configuration to each output' do
      logger = described_class.new(
        port: 1234,
        outputs: [
          { type: :udp },
          { type: :tcp }
        ]
      )

      logger.devices.each do |device|
        expect(device.port).to eq(1234)
      end
    end
  end
end
