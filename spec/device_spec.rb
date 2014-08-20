require 'logstash-logger'

describe LogStashLogger::Device do
  include_context 'device'

  context "when port is specified" do
    it "defaults type to UDP" do
      expect(device_with_port).to be_a LogStashLogger::Device::UDP
    end
  end

  context "when passing in configuration" do
    let(:configuration) { {type: :udp, port: port} }

    subject(:new_device) { described_class.new(configuration) }

    it "does not mutate the passed configuration" do
      expect{ new_device }.to_not change { configuration }
      expect( new_device ).to be_a LogStashLogger::Device::UDP
    end
  end

  context "when configuration type is a String" do
    let(:configuration) { {type: "udp", port: port} }

    subject(:new_device) { described_class.new(configuration) }

    it "is flexible and can except a device type that is a string" do
      expect(new_device).to be_a LogStashLogger::Device::UDP
    end
  end

end
