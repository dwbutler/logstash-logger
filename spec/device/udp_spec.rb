require 'logstash-logger'

describe LogStashLogger::Device::UDP do
  include_context 'device'

  it "writes to a UDP socket" do
    expect(udp_device.to_io).to be_a UDPSocket
  end
end
