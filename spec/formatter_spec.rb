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
      subject { described_class.new(formatter) }

      context "formatter class" do
        let(:formatter) { ::Logger::Formatter }

        it "returns a new instance of the class" do
          expect(subject).to be_a formatter
        end
      end

      context "formatter instance" do
        let(:formatter) { ::Logger::Formatter.new }

        it "returns the same formatter instance" do
          expect(subject).to eql(formatter)
        end

        it "supports tagged logging" do
          expect(subject).to be_a ::LogStashLogger::TaggedLogging::Formatter
        end
      end

      context "formatter proc" do
        let(:formatter) do
          proc { |severity, time, progname, msg| msg }
        end

        it "returns the same formatter proc" do
          expect(subject).to eql(formatter)
        end

        it "supports tagged logging" do
          expect(subject).to be_a ::LogStashLogger::TaggedLogging::Formatter
        end
      end

      context "formatter lambda" do
        let(:formatter) do
          ->(severity, time, progname, msg) { msg }
        end

        it "returns the same formatter lambda" do
          expect(subject).to eql(formatter)
        end

        it "supports tagged logging" do
          expect(subject).to be_a ::LogStashLogger::TaggedLogging::Formatter
        end
      end
    end
  end
end
