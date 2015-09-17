require 'rails/all'
require 'logstash-logger'
require 'logstash-logger/railtie'

module Test
  class Application < ::Rails::Application
    config.eager_load = false

    config.logstash.port = PORT
    config.log_level = :info
  end
end

Test::Application.initialize!

describe LogStashLogger do
  include_context 'device'

  describe "Rails integration" do
    let(:app) { Rails.application }
    let(:config) { app.config }
    subject { app.config.logger }

    before(:each) do
      app.config.logstash = ActiveSupport::OrderedOptions.new
      app.config.logger = nil
    end

    describe '#setup' do
      context "when configured with a port" do
        before(:each) do
          app.config.logstash.port = PORT
          app.config.log_level = :info
          LogStashLogger.setup(app)
        end

        it { is_expected.to be_a LogStashLogger }

        it "defaults level to config.log_level" do
          expect(subject.level).to eq(::Logger::INFO)
        end
      end

      context "when configured with a URI" do
        before(:each) do
          app.config.logstash.uri = tcp_uri
          LogStashLogger.setup(app)
        end

        it "configures the logger using the URI" do
          expect(subject.device).to be_a LogStashLogger::Device::TCP
        end
      end

      context "when configuring a multi delegator" do
        before(:each) do
          app.config.logstash.type = :multi_delegator
          app.config.logstash.outputs = [
            {
              type: :udp,
              uri: udp_uri
            },
            {
              type: :file,
              path: '/tmp/foo.log'
            }
          ]
          LogStashLogger.setup(app)
        end

        it "uses a multi delegator" do
          expect(subject.device).to be_a LogStashLogger::Device::MultiDelegator
          expect(subject.device.devices.map(&:class)).to eq([
            LogStashLogger::Device::UDP,
            LogStashLogger::Device::File
          ])
        end
      end

      context "when logstash is not configured" do
        before(:each) do
          LogStashLogger.setup(app)
        end

        it "does not configure anything" do
          expect(app.config.logger).to be_nil
        end
      end
    end
  end
end
