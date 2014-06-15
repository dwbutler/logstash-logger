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

  let(:file) { Tempfile.new('test') }
  let(:file_device) { LogStashLogger::Device.new(type: :file, path: file.path)}
end
