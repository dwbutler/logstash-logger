require 'pry'

RSpec.configure do |config|
  config.order = "random"

  config.before(:suite) do
    puts "Testing with #{CONNECTION_TYPE.to_s.upcase} socket type"
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

HOST = ENV['HOST'] || '0.0.0.0'
PORT = ENV.fetch('PORT', 5228).to_i
CONNECTION_TYPE ||= (ENV['TYPE'] || 'UDP').to_s.downcase.to_sym

RSpec.shared_context 'logger' do
  # The type of connection we're testing
  def connection_type
    CONNECTION_TYPE
  end

  let(:host) { HOST }
  let(:hostname) { Socket.gethostname }
  let(:port) { PORT }

  # The logstash logger
  let(:logger) { LogStashLogger.new(host: host, port: port, type: connection_type) }
  # The log device that the logger writes to
  let(:logdev) { logger.instance_variable_get(:@logdev) }
end

RSpec.shared_context 'device' do
  let(:port) { PORT }
  let(:device_with_port) { LogStashLogger::Device.new(port: port) }
  let(:udp_device) { LogStashLogger::Device.new(type: :udp, port: port) }
  let(:tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port) }
  let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, ssl_enable: true) }
  let(:unix_device) { LogStashLogger::Device.new(type: :unix, path: '/tmp/logstash') }

  let(:file) { Tempfile.new('test') }
  let(:file_device) { LogStashLogger::Device.new(type: :file, path: file.path)}

  let(:io_device) { LogStashLogger::Device.new(type: :io, io: io)}

  let(:redis_device) { LogStashLogger::Device.new(type: :redis, sync: true) }

  let(:udp_uri) { "udp://localhost:5228" }
  let(:tcp_uri) { "tcp://localhost:5229" }
  let(:unix_uri) { "unix:///some/path/to/socket" }
  let(:file_uri) { "file://#{file.path}" }
  let(:redis_uri) { "redis://localhost:6379" }
  let(:stdout_uri) { "stdout://localhost" }
  let(:stderr_uri) { "stderr://localhost" }

  let(:invalid_uri_config) { {uri: "non parsable uri"} }
  let(:udp_uri_config)     { {uri: udp_uri} }
  let(:tcp_uri_config)     { {uri: tcp_uri} }
  let(:unix_uri_config)    { {uri: unix_uri} }
  let(:file_uri_config)    { {uri: file_uri} }
  let(:redis_uri_config)   { {uri: redis_uri} }
  let(:stdout_uri_config)  { {uri: stdout_uri} }
  let(:stderr_uri_config)  { {uri: stderr_uri} }
end
