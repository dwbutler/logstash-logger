require 'logstash-logger'

describe LogStashLogger::Device::TCP do
  include_context 'device'

  let(:tcp_socket) { double('TCPSocket') }
  let(:ssl_socket) { double('SSLSocket') }

  before(:each) do
    allow(TCPSocket).to receive(:new) { tcp_socket }
    allow(tcp_socket).to receive(:sync=)

    allow(OpenSSL::SSL::SSLSocket).to receive(:new) { ssl_socket }
    allow(ssl_socket).to receive(:connect)
  end

  context "when not using SSL" do
    it "writes to a TCP socket" do
      expect(tcp_socket).to receive(:write)
      tcp_device.write('test')
    end

    it "returns false for #use_ssl?" do
      expect(tcp_device.use_ssl?).to be_falsey
    end
  end

  context "when using SSL" do
    it "writes to an SSL TCP socket" do
      expect(ssl_socket).to receive(:write)
      ssl_tcp_device.write('test')
    end

    it "returns false for #use_ssl?" do
      expect(ssl_tcp_device.use_ssl?).to be_truthy
    end
  end
end
