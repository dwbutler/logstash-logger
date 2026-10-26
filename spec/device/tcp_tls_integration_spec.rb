require 'logstash-logger'
require 'logger'
require 'socket'
require_relative '../support/tls_helper'

# Real TLS handshakes against a loopback server that presents a throwaway
# self-signed certificate. Nothing leaves 127.0.0.1.
describe LogStashLogger::Device::TCP, 'TLS verification against a real server' do
  before(:all) do
    @cert, @key = TLSHelper.self_signed(dns: ['localhost'], ips: [])
    @cert_file = TLSHelper.cert_file(@cert)
  end

  after(:all) { @cert_file.close! }

  let(:received) { Queue.new }
  let(:server) do
    tcp = TCPServer.new('127.0.0.1', 0)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = @cert
    ctx.key = @key
    OpenSSL::SSL::SSLServer.new(tcp, ctx)
  end
  let(:port) { server.to_io.addr[1] }

  before do
    srv = server
    q = received
    @server_thread = Thread.new do
      loop do
        begin
          client = srv.accept
          q << client.gets
          client.close
        rescue OpenSSL::SSL::SSLError, IOError, SystemCallError
          # A rejected handshake is expected in several examples
          break if srv.to_io.closed?
        end
      end
    end
  end

  after do
    server.close rescue nil
    @server_thread.kill
    @server_thread.join(1)
  end

  def device(**opts)
    LogStashLogger::Device.new(
      { type: :tcp, port: port, sync: true, buffer_flush_at_exit: false,
        error_logger: ::Logger.new(IO::NULL) }.merge(opts)
    )
  end

  def deliver(dev)
    dev.connect
    dev.io.write(%({"message":"hello"}\n))
    dev.io.flush
    line = received.pop(timeout: 5)
    dev.close!
    line
  end

  it 'refuses a self-signed certificate when only ssl_enable is set' do
    expect { device(host: 'localhost', ssl_enable: true).connect }
      .to raise_error(OpenSSL::SSL::SSLError)
  end

  it 'delivers when the certificate is trusted through ssl_certificate' do
    expect(deliver(device(host: 'localhost', ssl_certificate: @cert_file.path)))
      .to eq(%({"message":"hello"}\n))
  end

  it 'refuses a certificate whose name does not match the host' do
    expect { device(host: '127.0.0.1', ssl_certificate: @cert_file.path).connect }
      .to raise_error(OpenSSL::SSL::SSLError)
  end

  it 'checks the name given in verify_hostname when connecting by IP' do
    dev = device(host: '127.0.0.1', ssl_certificate: @cert_file.path, verify_hostname: 'localhost')
    expect(deliver(dev)).to eq(%({"message":"hello"}\n))
  end

  it 'still allows an explicit VERIFY_NONE context as an opt-out' do
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    dev = device(host: '127.0.0.1', ssl_context: ctx, verify_hostname: false)
    expect(deliver(dev)).to eq(%({"message":"hello"}\n))
  end
end
