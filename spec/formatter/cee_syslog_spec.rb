require 'logstash-logger'
require_relative '../support/unserializable_value'

describe LogStashLogger::Formatter::CeeSyslog do
  include_context "formatter"

  before { subject.error_logger = Logger.new(IO::NULL) }

  describe "#call" do
    it "outputs this host and the progname before the @cee" do
      expect(formatted_message).to start_with("#{hostname} #{progname}:@cee:")
    end

    it "serializes the LogStash::Event data as JSON" do
      json_data = formatted_message[/\A[^:]*:@cee:\s?(.*)\Z/, 1]
      json_message = JSON.parse(json_data)
      expect(json_message["message"]).to eq(message)
    end

    it "ends the record with exactly one newline" do
      expect(formatted_message.count("\n")).to eq(1)
      expect(formatted_message).to end_with("\n")
    end

    context "without progname" do
      let(:progname) { nil }

      it "only includes the hostname" do
        expect(formatted_message).to start_with("#{hostname}:@cee:")
      end
    end
  end

  describe "header" do
    context "when logged content sets host.hostname" do
      let(:message) { %q({"message":"hi","host":{"hostname":"web1\n<13>Jan  1 00:00:00 otherhost app: forged"}}) }

      it "uses this process's hostname, not the logged one" do
        expect(formatted_message).to start_with("#{hostname} #{progname}:@cee:")
      end

      it "cannot start a second record" do
        expect(formatted_message.count("\n")).to eq(1)
        expect(formatted_message).to end_with("\n")
      end
    end

    context "when logged content sets host to a String" do
      let(:message) { %q({"message":"hi","host":"web1"}) }

      it "formats the record normally" do
        expect(formatted_message).to start_with("#{hostname} #{progname}:@cee:")
        expect(JSON.parse(formatted_message[/@cee:(.*)\Z/, 1])['host']).to eq('web1')
      end
    end

    context "when the progname contains control characters" do
      let(:progname) { "app\n<13>forged" }

      it "keeps the header on one line" do
        expect(formatted_message.count("\n")).to eq(1)
        expect(formatted_message).to start_with("#{hostname} app <13>forged:@cee:")
      end
    end

    context "when a log call is made while another record is being built" do
      let(:formatter) { subject }
      let(:message) do
        f = formatter
        Object.new.tap do |obj|
          obj.define_singleton_method(:inspect) do
            f.call('INFO', Time.now, 'inner', 'nested')
            'outer message'
          end
        end
      end

      it "uses the outer call's progname in the outer header" do
        expect(subject.call(severity, time, 'outer', message)).to start_with("#{hostname} outer:@cee:")
      end
    end
  end

  describe "when the record cannot be serialized" do
    let(:message) { { 'message' => 'x', 'n' => UnserializableValue.new } }

    it "emits a placeholder in the same CEE/syslog framing" do
      expect(formatted_message).to start_with("#{hostname} #{progname}:@cee:")
      expect(formatted_message.count("\n")).to eq(1)
      data = JSON.parse(formatted_message[/@cee:(.*)\Z/, 1])
      expect(data['message']).to eq(LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_MSG)
      expect(data['tags']).to eq([LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_TAG])
    end
  end
end
