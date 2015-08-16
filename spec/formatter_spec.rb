require 'logstash-logger'

describe LogStashLogger::Formatter do
  describe "#new" do
    context "built in formatters" do
      it "returns a new JsonLines formatter" do
        expect(described_class.new(:json_lines)).to be_a LogStashLogger::Formatter::JsonLines
      end

      it "returns a new Json formatter" do
        expect(described_class.new(:json)).to be_a LogStashLogger::Formatter::Json
      end

      it "returns a new Cee formatter" do
        expect(described_class.new(:cee)).to be_a LogStashLogger::Formatter::Cee
      end

      it "returns a new CeeSyslog formatter" do
        expect(described_class.new(:cee_syslog)).to be_a LogStashLogger::Formatter::CeeSyslog
      end

      it "returns a new LogStashEvent formatter" do
        expect(described_class.new(:logstash_event)).to be_a LogStashLogger::Formatter::LogStashEvent
      end
    end

    context "custom formatter" do
      it "returns a new instance of a custom formatter class" do
        expect(described_class.new(::Logger::Formatter)).to be_a ::Logger::Formatter
      end

      it "returns the same formatter instance if a custom formatter instance is passed in" do
        formatter = ::Logger::Formatter.new
        expect(described_class.new(formatter)).to eql(formatter)
      end

      it "returns a formatter proc if it is passed in" do
        formatter = proc do |serverity, time, progname, msg|
          msg
        end
        expect(described_class.new(formatter)).to eql(formatter)
      end
    end
  end
end
