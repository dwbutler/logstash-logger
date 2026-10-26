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
    allow(ssl_socket).to receive(:connect_nonblock).with(exception: false) { ssl_socket }
    allow(ssl_socket).to receive(:post_connection_check)
    allow(ssl_socket).to receive(:sync_close=)
    allow(ssl_socket).to receive(:hostname=)
    allow(tcp_socket).to receive(:close)
    allow(ssl_tcp_device).to receive(:warn)
  end

  context "when not using SSL" do
    it "writes to a TCP socket" do
      expect(tcp_socket).to receive(:write_nonblock).with('test', exception: false).and_return(4)
      tcp_device.write('test')
    end

    it "gives up after write_timeout even while partial writes keep succeeding" do
      device = LogStashLogger::Device.new(type: :tcp, port: port, sync: true, write_timeout: 0.2)
      allow(tcp_socket).to receive(:write_nonblock) { sleep 0.05; 1 }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { device.write_one('x' * 100) }.to raise_error(IO::TimeoutError)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
    end

    it "writes with a plain blocking write when write_timeout is nil" do
      device = LogStashLogger::Device.new(type: :tcp, port: port, sync: true, write_timeout: nil)
      expect(tcp_socket).to receive(:write).with('test')
      device.write('test')
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
      expect(ssl_socket).to receive(:write_nonblock).with('test', exception: false).and_return(4)
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

  context 'connect timeout' do
    it 'gives up connecting after 5 seconds by default' do
      expect(TCPSocket).to receive(:new).with(anything, port, hash_including(connect_timeout: 5)) { tcp_socket }
      tcp_device.connect
    end

    it 'uses the connect_timeout option' do
      device = LogStashLogger::Device.new(type: :tcp, port: port, sync: true, connect_timeout: 0.5)
      expect(TCPSocket).to receive(:new).with(anything, port, hash_including(connect_timeout: 0.5)) { tcp_socket }
      device.connect
    end

    it 'waits for the operating system when connect_timeout is nil' do
      device = LogStashLogger::Device.new(type: :tcp, port: port, sync: true, connect_timeout: nil)
      expect(TCPSocket).to receive(:new).with(anything, port, hash_including(connect_timeout: nil)) { tcp_socket }
      device.connect
    end

    it 'also bounds name resolution on MRI' do
      skip 'JRuby has no resolv_timeout' unless RUBY_ENGINE == 'ruby'
      expect(TCPSocket).to receive(:new).with(anything, port, connect_timeout: 5, resolv_timeout: 5) { tcp_socket }
      tcp_device.connect
    end

    it 'accepts a number given as a string, as in a URI query' do
      device = LogStashLogger::Device.new(uri: "tcp://localhost:#{port}?connect_timeout=2.5")
      expect(device.connect_timeout).to eq(2.5)
    end

    it 'rejects a timeout that is not a positive number' do
      ['soon', 0, -1, true].each do |value|
        expect {
          LogStashLogger::Device.new(type: :tcp, port: port, connect_timeout: value)
        }.to raise_error(ArgumentError, /connect_timeout must be a positive number of seconds/)
      end
    end
  end
end
