require 'logstash-logger'
require 'logger'
require 'socket'
require_relative '../support/tls_helper'

# A loopback peer that accepts connections and never reads from them, so the
# logger's writes block once the socket buffers are full.
describe 'Socket outputs with a peer that stops reading' do
  let(:big_record) { ('x' * (8 * 1024 * 1024)) + "\n" }
  let(:held) { Queue.new }

  after do
    @server.close rescue nil
    @server_thread&.kill
    @server_thread&.join(1)
    held.size.times { held.pop.close rescue nil }
  end

  def start_server(server)
    @server = server
    @server_thread = Thread.new do
      loop { held << server.accept }
    rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
      nil
    end
  end

  def device(**opts)
    LogStashLogger::Device.new(
      { type: :tcp, host: '127.0.0.1', sync: true, buffer_flush_at_exit: false,
        write_timeout: 0.5, error_logger: ::Logger.new(IO::NULL) }.merge(opts)
    )
  end

  # Runs the write in a thread so that a write with no deadline fails the
  # example instead of hanging the suite.
  def expect_write_to_time_out(dev)
    writer = Thread.new do
      dev.write_one(big_record)
    rescue IO::TimeoutError => e
      e
    end
    finished = writer.join(3)
    writer.kill unless finished
    expect(finished && writer.value).to be_a(IO::TimeoutError)
    expect(dev).not_to be_connected
  end

  it 'gives up on a TCP write after write_timeout' do
    start_server(TCPServer.new('127.0.0.1', 0))
    expect_write_to_time_out(device(port: @server.addr[1]))
  end

  it 'gives up on a TLS write after write_timeout' do
    cert, key = TLSHelper.self_signed(dns: [], ips: ['127.0.0.1'])
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = cert
    ctx.key = key
    tcp = TCPServer.new('127.0.0.1', 0)
    start_server(OpenSSL::SSL::SSLServer.new(tcp, ctx))
    client_ctx = OpenSSL::SSL::SSLContext.new
    client_ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    expect_write_to_time_out(device(port: tcp.addr[1], ssl_context: client_ctx, verify_hostname: false))
  end

  it 'gives up on a Unix socket write after write_timeout' do
    client, peer = UNIXSocket.pair
    held << peer
    allow(UNIXSocket).to receive(:new).and_return(client)
    expect_write_to_time_out(device(type: :unix, path: '/nonexistent/logstash.sock'))
  end
end
