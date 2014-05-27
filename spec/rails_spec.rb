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
  describe "Rails integration", Test::Application do
    let(:app) { Rails.application }
    let(:config) { app.config }

    describe 'Railtie' do
      describe 'Rails.logger' do
        subject { Rails.logger }

        it { should be_a LogStashLogger }
        its(:level) { should eq(::Logger::INFO) }
      end
    end

    describe '#setup' do
      before do
        app.config.logstash.port = PORT
        LogStashLogger.setup(app)
      end

      it "defaults logstash host to localhost" do
        expect(config.logstash.host).to eq("localhost")
      end

      it "defaults logstash type to :udp" do
        expect(config.logstash.type).to eq(:udp)
      end

      context "when logstash is not configured" do
        before do
          app.config.logstash.clear
          app.config.logger = nil
          LogStashLogger.setup(app)
        end

        it "does not configure anything" do
          expect(app.config.logger).to be_nil
        end
      end

      context "when port is not specified" do
        before(:each) do
          app.config.logstash.clear
          app.config.logstash.host = 'localhost'
        end

        it "raises an exception" do
          expect { LogStashLogger.setup(app) }.to raise_error(ArgumentError)
        end
      end
    end
  end
end