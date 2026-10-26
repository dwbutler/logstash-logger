require 'logstash-logger'
require 'logger'
require 'socket'
require_relative '../support/tls_helper'

# Process.pid is stubbed so this runs on every Ruby, JRuby included, which
# cannot fork.
describe LogStashLogger::Device::Connectable, 'connection in a forked process' do
  let(:accepted) { Queue.new }

  before do
    @tcp_server = TCPServer.new('127.0.0.1', 0)
  end

  after do
    @tcp_server.close rescue nil
    @accept_thread&.kill
  end

  def accept_with(server)
    @accept_thread = Thread.new do
      loop { accepted << server.accept }
    rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
      nil
    end
  end

  def device(**opts)
    LogStashLogger::Device.new(
      { type: :tcp, host: '127.0.0.1', port: @tcp_server.addr[1], sync: true,
        buffer_flush_at_exit: false, error_logger: ::Logger.new(IO::NULL) }.merge(opts)
    )
  end

  def as_child
    # Block form: the timer thread may call Process.pid while the stub is set up
    child_pid = Process.pid + 1
    allow(Process).to receive(:pid) { child_pid }
  end

  it 'opens its own connection and writes nothing on the inherited one' do
    accept_with(@tcp_server)
    dev = device
    dev.write("parent\n")
    inherited = accepted.pop(timeout: 5)
    expect(inherited.gets).to eq("parent\n")

    as_child
    dev.write("child\n")
    own = accepted.pop(timeout: 5)
    expect(own.gets).to eq("child\n")
    expect(inherited.read_nonblock(100, exception: false)).to be_nil.or eq(:wait_readable)
  end

  it 'does not end the inherited TLS session' do
    cert, key = TLSHelper.self_signed(dns: [], ips: ['127.0.0.1'])
    server_ctx = OpenSSL::SSL::SSLContext.new
    server_ctx.cert = cert
    server_ctx.key = key
    accept_with(OpenSSL::SSL::SSLServer.new(@tcp_server, server_ctx))
    client_ctx = OpenSSL::SSL::SSLContext.new
    client_ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    dev = device(ssl_context: client_ctx, verify_hostname: false)
    dev.write("parent\n")
    expect(accepted.pop(timeout: 5).gets).to eq("parent\n")
    inherited = dev.io
    expect(inherited).not_to receive(:close)

    as_child
    dev.write("child\n")
    expect(accepted.pop(timeout: 5).gets).to eq("child\n")
    dev.close
  end

  it 'does not end the inherited TLS session when close! is called directly' do
    cert, key = TLSHelper.self_signed(dns: [], ips: ['127.0.0.1'])
    server_ctx = OpenSSL::SSL::SSLContext.new
    server_ctx.cert = cert
    server_ctx.key = key
    accept_with(OpenSSL::SSL::SSLServer.new(@tcp_server, server_ctx))
    client_ctx = OpenSSL::SSL::SSLContext.new
    client_ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    dev = device(ssl_context: client_ctx, verify_hostname: false)
    dev.write("parent\n")
    expect(accepted.pop(timeout: 5).gets).to eq("parent\n")
    expect(dev.io).not_to receive(:close)

    as_child
    dev.close!
  end

  it 'releases the inherited connection when connect is called directly' do
    dev = device(type: :unix, path: '/nonexistent/logstash.sock')
    inherited, peer = UNIXSocket.pair
    dev.instance_variable_set(:@io, inherited)
    allow(UNIXSocket).to receive(:new).and_return(UNIXSocket.pair.first)

    as_child
    dev.connect

    expect(inherited).to be_closed
    peer.close
  end

  it 'hands out a new connection from #io' do
    accept_with(@tcp_server)
    dev = device
    dev.write("parent\n")
    inherited = dev.io

    as_child
    expect(dev.io).not_to equal(inherited)
  end
end
