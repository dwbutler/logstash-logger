require 'logstash-logger'

describe LogStashLogger::Device do
  include_context 'device'

  context "when port is specified" do
    it "defaults type to UDP" do
      expect(device_with_port).to be_a LogStashLogger::Device::UDP
    end
  end
end
