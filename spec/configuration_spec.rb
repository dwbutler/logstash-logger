require 'logstash-logger'

describe LogStashLogger do
  describe "#configure" do
    it 'auto initializes' do
      config = LogStashLogger.configure
      expect(config).to be_a LogStashLogger::Configuration
      expect(LogStashLogger.configuration).to eq(config)
    end

    describe LogStashLogger::Configuration do
      describe "#customize_event" do
        it 'allows each LogStash::Event to be customized' do
          config = LogStashLogger.configure do |config|
            config.customize_event do |event|
              event["test1"] = "response1"
            end
          end

          event = LogStash::Event.new({})
          config.customize_event_block.call(event)
          expect(event["test1"]).to eq("response1")
        end
      end
    end
  end
end
