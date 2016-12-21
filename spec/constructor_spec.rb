require 'logstash-logger'

describe LogStashLogger do
  describe ".new" do
    it "returns a Logger instance" do
      expect(LogStashLogger.new(type: :stdout)).to be_a ::Logger
    end

    context "type: :multi_logger" do
      it "returns an instance of LogStashLogger::MultiLogger" do
        expect(LogStashLogger.new(type: :multi_logger)).to be_a LogStashLogger::MultiLogger
      end

      it "merges top level configuration into each logger" do
        logger = LogStashLogger.new(type: :multi_logger, port: 1234, outputs: [ { type: :tcp  }, { type: :udp } ])
        logger.loggers.each do |logger|
          expect(logger.device.port).to eq(1234)
        end
      end
    end
  end
end
