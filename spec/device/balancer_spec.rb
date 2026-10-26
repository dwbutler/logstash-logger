require 'logstash-logger'

describe LogStashLogger::Device::Balancer do
  include_context 'device'

  # Create a Balancer writing to both STDOUT and a StringIO
  subject { balancer_device }

  describe '#write' do
    before do
      allow(subject.devices).to receive(:sample) { io }
    end

    it "writes to one device" do
      expect(io).to receive(:write).once
      expect($stdout).to_not receive(:write)
      subject.write("log message")
    end
  end

  context "when an output raises" do
    let(:error_io) { StringIO.new }
    let(:error_logger) { ::Logger.new(error_io) }
    let(:failing_io) { StringIO.new }
    let(:device) do
      LogStashLogger::Device.new(
        type: :balancer,
        error_logger: error_logger,
        outputs: [
          { type: :io, io: failing_io },
          { type: :io, io: io }
        ]
      )
    end

    it "fails over to another output and reports the error" do
      allow(failing_io).to receive(:write).and_raise(Errno::ENOSPC)
      allow(device.devices).to receive(:sample) { device.devices.first }

      expect { 3.times { device.write("test") } }.not_to raise_error

      expect(io.string).to eq("test" * 3)
      expect(error_io.string.scan("Errno::ENOSPC").size).to eq(3)
    end

    it "still flushes the other outputs and reports the error" do
      allow(failing_io).to receive(:flush).and_raise(Errno::ENOSPC)
      expect(io).to receive(:flush).once

      expect { device.flush }.not_to raise_error

      expect(error_io.string.scan("Errno::ENOSPC").size).to eq(1)
    end

    it "still fails over when the error_logger raises" do
      allow(failing_io).to receive(:write).and_raise(Errno::ENOSPC)
      allow(error_logger).to receive(:error).and_raise(IOError, "closed stream")
      allow(device.devices).to receive(:sample) { device.devices.first }

      expect { device.write("test") }.to output(/Errno::ENOSPC/).to_stderr

      expect(io.string).to eq("test")
    end
  end

  describe '#flush, #close' do
    [:flush, :close].each do |method_name|
      it "call on all devices" do
        subject.devices.each do |device|
          expect(device).to receive(method_name).once
        end
        subject.send(method_name)
      end
    end
  end
end
