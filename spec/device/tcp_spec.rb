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
    allow(ssl_socket).to receive(:post_connection_check)
    allow(ssl_tcp_device).to receive(:warn)
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

    it "returns true for #use_ssl?" do
      expect(ssl_tcp_device.use_ssl?).to be_truthy
    end

    it 'provides a warning about using a SSL context' do
      expect(ssl_tcp_device).to receive(:warn).with("[DEPRECATION] 'LogStashLogger::Device::Socket' should be instantiated with a SSL context for hostname verification.")
      ssl_tcp_device.connect
    end

    context 'with a provided SSL context' do
      let(:ssl_context) { 'test_ssl_context' }
      let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, sync: true, ssl_context: ssl_context) }

      it "checks ssl certificate validity" do
        expect(ssl_socket).to receive(:post_connection_check).with(HOST)
        ssl_tcp_device.connect
      end

      it 'creates the socket using that context' do
        expect(OpenSSL::SSL::SSLSocket).to receive(:new).with(tcp_socket, ssl_context)
        ssl_tcp_device.connect
      end

      it 'implicitly sets @use_ssl to true' do
        expect(ssl_tcp_device.use_ssl?).to be_truthy
      end

      context 'and :ssl_enable explicitly set to false' do
        let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, sync: true, ssl_enable: false, ssl_context: ssl_context) }

        it 'explicitly sets @use_ssl to false' do
          expect(ssl_tcp_device.use_ssl?).to be_falsey
        end
      end
    end
  end

end
