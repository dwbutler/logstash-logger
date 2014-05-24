require 'rubygems'
require 'bundler/setup'

require 'logstash-logger'
require 'pry'

RSpec.configure do |config|
  config.order = "random"
end

RSpec.shared_context 'logger' do
  # The type of socket we're testing
  def socket_type
    @socket_type ||= (ENV['SOCKET_TYPE'] || 'UDP').to_s.downcase.to_sym
  end

  let(:host) { '0.0.0.0' }
  let(:hostname) { Socket.gethostname }
  let(:port) { 5228 }

  # The logstash logger
  let(:logger) { LogStashLogger.new(host, port, socket_type) }
  # The log device that the logger writes to
  let(:logdev) { logger.instance_variable_get(:@logdev) }
end