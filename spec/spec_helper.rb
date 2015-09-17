require 'pry'

require 'simplecov'
SimpleCov.start
if ENV['CI']=='true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

RSpec.configure do |config|
  config.order = "random"

  config.before(:suite) do
    puts "Testing with #{CONNECTION_TYPE.to_s.upcase} socket type"
  end

  config.before(:each) do
    LogStashLogger.configure do

    end
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
  let(:logger) { LogStashLogger.new(host: host, port: port, type: connection_type, sync: true) }
  # The log device that the logger writes to
  let(:logdev) { logger.instance_variable_get(:@logdev) }
end

RSpec.shared_context 'device' do
  let(:port) { PORT }
  let(:device_with_port) { LogStashLogger::Device.new(port: port) }
  let(:udp_device) { LogStashLogger::Device.new(type: :udp, port: port, sync: true) }
  let(:tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, sync: true) }
  let(:ssl_tcp_device) { LogStashLogger::Device.new(type: :tcp, port: port, ssl_enable: true, sync: true) }
  let(:unix_device) { LogStashLogger::Device.new(type: :unix, path: '/tmp/logstash', sync: true) }

  let(:file) { Tempfile.new('test') }
  let(:file_device) { LogStashLogger::Device.new(type: :file, path: file.path)}

  let(:io) { StringIO.new }
  let(:io_device) { LogStashLogger::Device.new(type: :io, io: io)}

  let(:redis_device) { LogStashLogger::Device.new(type: :redis, sync: true) }
  let(:kafka_device) { LogStashLogger::Device.new(type: :kafka, sync: true) }

  let(:outputs) { [{type: :stdout}, {type: :io, io: io}] }
  let(:multi_delegator_device) { LogStashLogger::Device.new(type: :multi_delegator, outputs: outputs) }
  let(:balancer_device) { LogStashLogger::Device.new(type: :balancer, outputs: outputs) }
  let(:multi_logger) do
    LogStashLogger.new(
        type: :multi_logger,
        outputs: [
            { type: :stdout, formatter: ::Logger::Formatter },
            { type: :io, io: io }
        ]
    )
  end

  let(:udp_uri) { "udp://localhost:5228" }
  let(:tcp_uri) { "tcp://localhost:5229" }
  let(:unix_uri) { "unix:///some/path/to/socket" }
  let(:file_uri) { "file://#{file.path}" }
  let(:redis_uri) { "redis://localhost:6379" }
  let(:kafka_uri) { "kafka://localhost:9092" }
  let(:stdout_uri) { "stdout://localhost" }
  let(:stderr_uri) { "stderr://localhost" }

  let(:invalid_uri_config) { {uri: "non parsable uri"} }
  let(:udp_uri_config)     { {uri: udp_uri} }
  let(:tcp_uri_config)     { {uri: tcp_uri} }
  let(:unix_uri_config)    { {uri: unix_uri} }
  let(:file_uri_config)    { {uri: file_uri} }
  let(:redis_uri_config)   { {uri: redis_uri} }
  let(:kafka_uri_config)   { {uri: kafka_uri} }
  let(:stdout_uri_config)  { {uri: stdout_uri} }
  let(:stderr_uri_config)  { {uri: stderr_uri} }
end

RSpec.shared_context 'formatter' do
  let(:severity) { "DEBUG" }
  let(:time) { Time.now }
  let(:progname) { "ruby" }
  let(:message) { "foo" }
  let(:hostname) { Socket.gethostname }
  let(:formatted_message) do
    subject.call(severity, time, progname, message)
  end
end
