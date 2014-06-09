require 'logstash-logger'

describe LogStashLogger::Device do
  include_context 'logger'

  it "defaults type to UDP" do
    expect(device).to be_a LogStashLogger::Device::UDP
  end

  describe LogStashLogger::Device::Socket do
    it "defaults host to 0.0.0.0" do
      expect(device.host).to eq("0.0.0.0")
    end

    context "when port is not specified" do
      it "raises an exception" do
        expect { described_class.new }.to raise_error
      end
    end
  end
end
