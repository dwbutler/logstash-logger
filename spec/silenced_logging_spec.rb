require 'logstash-logger'
require 'active_support'

describe LogStashLogger do
  include_context 'logger'

  describe "silenced logging" do

    it "yields the logger" do
      logger.silence do |yielded|
        expect(yielded).to eq(logger)
      end
    end

    it "silences any message below ERROR level by default" do
      logger.silence do
        expect(logger.device).to receive(:write).once
        logger.info("info")
        logger.warn("warning")
        logger.error("error")
      end
    end

    it "takes a custom log level to silence to" do
      logger.silence(::Logger::WARN) do
        expect(logger.device).to receive(:write).once
        logger.info("info")
        logger.warn("warning")
      end
    end

    it "restores the outer level when a nested silence ends" do
      logger.silence(::Logger::ERROR) do
        logger.silence(::Logger::WARN) { }

        expect(logger.device).to receive(:write).once
        logger.warn("warning")
        logger.error("error")
      end
      expect(logger.level).to eq(::Logger::DEBUG)
    end
  end

  describe "silencing through ActiveSupport::BroadcastLogger" do
    let(:io) { StringIO.new }
    let(:io_logger) { LogStashLogger.new(type: :io, io: io) }
    let(:broadcast) { ActiveSupport::BroadcastLogger.new(io_logger) }

    it "does not write records below the temporary level" do
      broadcast.silence do
        broadcast.info("silenced info")
        broadcast.warn("silenced warning")
        broadcast.error("kept error")
      end

      expect(io.string).not_to include("silenced")
      expect(io.string).to include("kept error")
    end

    it "writes records at the configured level after the block" do
      broadcast.silence { }
      broadcast.info("after silence")

      expect(io.string).to include("after silence")
    end
  end

  describe "#local_level=" do
    it "accepts an Integer, a Symbol or nil" do
      logger.local_level = ::Logger::WARN
      expect(logger.level).to eq(::Logger::WARN)

      logger.local_level = :error
      expect(logger.local_level).to eq(::Logger::ERROR)

      logger.local_level = nil
      expect(logger.local_level).to be_nil
      expect(logger.level).to eq(::Logger::DEBUG)
    end

    it "rejects other values" do
      expect { logger.local_level = "error" }.to raise_error(ArgumentError)
    end
  end
end
