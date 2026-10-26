require 'logstash-logger'

describe LogStashLogger::Device::MultiDelegator do
  include_context 'device'

  # Create a MultiDelegator writing to both STDOUT and a StringIO
  subject { multi_delegator_device }

  it "writes to all outputs" do
    expect($stdout).to receive(:write).once
    expect(io).to receive(:write).once

    subject.write("test")
  end

  context "when an output raises" do
    let(:error_io) { StringIO.new }
    let(:error_logger) { ::Logger.new(error_io) }
    let(:failing_io) { StringIO.new }
    let(:device) do
      LogStashLogger::Device.new(
        type: :multi_delegator,
        error_logger: error_logger,
        outputs: [
          { type: :io, io: failing_io },
          { type: :io, io: io }
        ]
      )
    end

    it "still writes to the other outputs and reports the error" do
      allow(failing_io).to receive(:write).and_raise(Errno::ENOSPC)

      expect { device.write("test") }.not_to raise_error

      expect(io.string).to eq("test")
      expect(error_io.string.scan("Errno::ENOSPC").size).to eq(1)
    end

    it "still flushes the other outputs and reports the error" do
      allow(failing_io).to receive(:flush).and_raise(Errno::ENOSPC)
      expect(io).to receive(:flush).once

      expect { device.flush }.not_to raise_error

      expect(error_io.string.scan("Errno::ENOSPC").size).to eq(1)
    end

    it "still writes to the other outputs when the error_logger raises" do
      allow(failing_io).to receive(:write).and_raise(Errno::ENOSPC)
      allow(error_logger).to receive(:error).and_raise(IOError, "closed stream")

      expect { device.write("test") }.to output(/Errno::ENOSPC/).to_stderr

      expect(io.string).to eq("test")
    end
  end

  describe "#reset" do
    it "resets each output so they all keep writing" do
      logger = LogStashLogger.new(
        type: :multi_delegator,
        outputs: [
          { type: :file, path: file.path, sync: true },
          { type: :io, io: io }
        ]
      )

      logger.reset
      logger.info("after reset")

      expect(::File.read(file.path)).to include("after reset")
      expect(io).not_to be_closed
      expect(io.string).to include("after reset")
    end
  end

  describe ".new" do
    it "merges top level configuration to each output" do
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
