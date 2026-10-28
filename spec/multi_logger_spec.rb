require 'logstash-logger'
require 'active_support'
require 'stringio'

describe LogStashLogger::MultiLogger do
  include_context 'device'

  # Create a MultiLogger writing to both STDOUT and a StringIO
  subject { multi_logger }

  it { is_expected.to be_a LogStashLogger::MultiLogger }

  it "has multiple loggers" do
    expect(subject.loggers.count).to eq(2)
  end

  it "has one logger per output" do
    expect(subject.loggers[0].device).to be_a LogStashLogger::Device::Stdout
    expect(subject.loggers[1].device).to be_a LogStashLogger::Device::IO
  end

  it "allows a different formatter for each logger" do
    expect(subject.loggers[0].formatter.class).to eq ::Logger::Formatter
    expect(subject.loggers[1].formatter.class).to eq LogStashLogger::Formatter::JsonLines
  end

  it "logs to all loggers" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:info).with("test")
    end

    subject.info("test")
  end

  it "supports silenced logging" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:silence).and_call_original
      expect(logger.device).to receive(:write).once
    end

    subject.silence(::Logger::WARN) do |logger|
      expect(logger).to eq(subject)
      logger.info 'info'
      logger.warn 'warning'
    end
  end

  it "is silenced through ActiveSupport::BroadcastLogger" do
    ios = [StringIO.new, StringIO.new]
    multi = LogStashLogger.new(type: :multi_logger, outputs: ios.map { |io| { type: :io, io: io } })
    broadcast = ActiveSupport::BroadcastLogger.new(multi)

    broadcast.silence do
      broadcast.info("silenced info")
      broadcast.error("kept error")
    end
    broadcast.info("after silence")

    ios.each do |io|
      expect(io.string).not_to include("silenced")
      expect(io.string).to include("kept error", "after silence")
    end
  end

  it "supports tagged logging" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:tagged).with('tag').and_call_original
      expect(logger.device).to receive(:write) do |event_string|
        event = JSON.parse(event_string)
        expect(event['tags']).to match_array(['tag'])
      end
    end

    subject.tagged('tag') do |logger|
      logger.info 'test'
    end
  end

  it "can call .reset on each logger" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:reset).and_call_original
    end

    subject.reset
  end

  it "can be reset through ActiveSupport::BroadcastLogger" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:reset)
    end

    ActiveSupport::BroadcastLogger.new(subject).reset
  end

  it "delegates #log to loggers" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:add).with(::Logger::DEBUG, "test", nil)
    end

    subject.log(::Logger::DEBUG, "test")
  end
end
