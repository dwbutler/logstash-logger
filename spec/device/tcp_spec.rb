require 'logstash-logger'

describe LogStashLogger::Device::TCP do
  include_context 'device'

  let!(:tcp_server) do
    TCPServer.new(tcp_device.port)
  end

  it "writes to a TCP socket" do
    expect(tcp_device.to_io).to be_a TCPSocket
  end
end
