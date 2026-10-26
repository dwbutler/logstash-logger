require 'logstash-logger'
require_relative '../support/tls_helper'

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
    allow(ssl_socket).to receive(:sync_close=)
    allow(ssl_socket).to receive(:hostname=)
    allow(tcp_socket).to receive(:close)
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

    it "exposes the TCP socket via #io" do
      expect(tcp_device.io).to eq tcp_socket
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

    it "exposes the SSL socket via #io" do
      expect(ssl_tcp_device.io).to eq ssl_socket
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
      it 'uses a context that verifies the server certificate' do
        ctx = ssl_tcp_device.ssl_context
        expect(ctx).to be_a(OpenSSL::SSL::SSLContext)
        expect(ctx.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(ctx.verify_hostname).to be true
        expect(ctx.cert_store).not_to be_nil
      end

      it 'creates the socket with that context' do
        expect(OpenSSL::SSL::SSLSocket).to receive(:new).with(tcp_socket, ssl_tcp_device.ssl_context)
        ssl_tcp_device.connect
      end

      it 'verifies the hostname after connecting' do
        expect(ssl_socket).to receive(:post_connection_check).with(HOST)
        ssl_tcp_device.connect
      end

      context 'with verify_hostname: false' do
        let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, ssl_enable: true, sync: true, verify_hostname: false) }

        it 'still verifies the certificate chain' do
          expect(ssl_tcp_device.ssl_context.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
        end

        it 'does not verify the hostname' do
          expect(ssl_tcp_device.ssl_context.verify_hostname).to be false
          expect(ssl_socket).not_to receive(:post_connection_check)
          ssl_tcp_device.connect
        end
      end
    end

    context 'server name indication' do
      it 'is sent for a DNS hostname' do
        device = LogStashLogger::Device.new(type: :tcp, host: 'logstash.example.com', port: port, ssl_enable: true, sync: true)
        expect(ssl_socket).to receive(:hostname=).with('logstash.example.com')
        device.connect
      end

      it 'is not sent for an IP address' do
        expect(ssl_socket).not_to receive(:hostname=)
        ssl_tcp_device.connect
      end
    end

    it 'closes the TCP socket together with the SSL socket' do
      expect(ssl_socket).to receive(:sync_close=).with(true)
      ssl_tcp_device.connect
    end

    context 'when the SSL socket cannot be created' do
      before do
        allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_raise(OpenSSL::SSL::SSLError, 'boom')
      end

      it 'closes the TCP socket it opened' do
        expect(tcp_socket).to receive(:close).once
        expect { ssl_tcp_device.connect }.to raise_error(OpenSSL::SSL::SSLError)
      end
    end

    context 'only providing a certificate file' do
      let(:cert_file) { TLSHelper.cert_file(TLSHelper.self_signed.first) }
      let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, ssl_enable: true, sync: true, ssl_certificate: cert_file.path) }

      after { cert_file.close! }

      it 'trusts that certificate and verifies the server against it' do
        ctx = ssl_tcp_device.ssl_context
        expect(ctx.ca_file).to eq(cert_file.path)
        expect(ctx.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(ctx.verify_hostname).to be true
      end

      it 'enables SSL implicitly' do
        device = LogStashLogger::Device.new(type: :tcp, port: port, sync: true, ssl_certificate: cert_file.path)
        expect(device.use_ssl?).to be_truthy
      end

      it 'rejects a missing file' do
        expect {
          LogStashLogger::Device.new(type: :tcp, port: port, sync: true, ssl_certificate: '/nonexistent/cert.pem')
        }.to raise_error(ArgumentError, /readable certificate file/)
      end

      it 'rejects a file that is not a certificate' do
        not_a_cert = Tempfile.new('not-a-cert')
        not_a_cert.write('hello')
        not_a_cert.flush
        expect {
          LogStashLogger::Device.new(type: :tcp, port: port, sync: true, ssl_certificate: not_a_cert.path)
        }.to raise_error(ArgumentError, /not a PEM or DER certificate/)
      ensure
        not_a_cert.close!
      end
    end
  end

end
