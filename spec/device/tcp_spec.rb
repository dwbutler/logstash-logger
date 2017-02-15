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

    context 'hostname validation' do
      let(:ssl_context) { double('test_ssl_context', verify_mode: OpenSSL::SSL::VERIFY_PEER) }
      let(:ssl_tcp_options) { { type: :tcp, port: port, sync: true, ssl_context: ssl_context } }

      context 'is enabled by default' do
        let(:ssl_tcp_device) { LogStashLogger::Device.new(ssl_tcp_options) }

        it 'validates' do
          expect(ssl_tcp_device.send(:verify_hostname?)).to be_truthy
          expect(ssl_socket).to receive(:post_connection_check).with HOST
          ssl_tcp_device.connect
        end
      end

      context 'is disabled explicitly' do
        let(:ssl_tcp_device) { LogStashLogger::Device.new(ssl_tcp_options.merge(verify_hostname: false)) }

        it 'does not validate' do
          expect(ssl_tcp_device.send(:verify_hostname?)).to be_falsey
          expect(ssl_socket).not_to receive(:post_connection_check)
          ssl_tcp_device.connect
        end
      end

      context 'is implicitly enabled by providing a hostname' do
        let(:hostname) { 'www.example.com' }
        let(:ssl_tcp_device) { LogStashLogger::Device.new(ssl_tcp_options.merge(verify_hostname: hostname)) }

        it 'validates with supplied hostname' do
          expect(ssl_socket).to receive(:post_connection_check).with hostname
          ssl_tcp_device.connect
        end
      end
    end

    context 'with a provided SSL context' do
      let(:ssl_context) { double('test_ssl_context', verify_mode: OpenSSL::SSL::VERIFY_PEER) }
      let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, sync: true, ssl_context: ssl_context) }

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

    context 'without a provided SSL context' do
      it 'ssl_context returns nil' do
        expect(ssl_tcp_device.ssl_context).to be_nil
      end
    end

    context 'only providing a certificate file' do
      let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, ssl_enable: true, sync: true, ssl_certificate: '/path/to/cert.pem') }

      it 'implicitly uses a context with the configured certificate' do
        expect(ssl_tcp_device.ssl_context.cert).to eq('/path/to/cert.pem')
      end
    end
  end

end
