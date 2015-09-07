require 'logstash-logger'

describe LogStashLogger::Device::Socket do
  include_context 'device'

  it "defaults host to 0.0.0.0" do
    expect(device_with_port.host).to eq("0.0.0.0")
  end

  context "when port is not specified" do
    it "raises an exception" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end
end
