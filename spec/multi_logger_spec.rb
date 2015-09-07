require 'logstash-logger'

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
    expect(subject.loggers[0].formatter).to be_a ::Logger::Formatter
    expect(subject.loggers[1].formatter).to be_a LogStashLogger::Formatter::JsonLines
  end

  it "logs to all loggers" do
    subject.loggers.each do |logger|
      expect(logger).to receive(:info).with("test")
    end

    multi_logger.info("test")
  end

  context "tagged logging" do
    it "forwards tags to each logger's formatter" do
      subject.loggers.each do |logger|
        expect(logger.formatter).to receive(:tagged).with("foo")
      end

      subject.tagged("foo") do |logger|
        logger.debug("bar")
      end
    end

    it "clears tags on each logger's formatter when flushing" do
      subject.loggers.each do |logger|
        expect(logger.formatter).to receive(:clear_tags!)
      end

      subject.flush
    end
  end
end
