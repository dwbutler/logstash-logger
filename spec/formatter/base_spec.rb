require 'logstash-logger'

describe LogStashLogger::Formatter::Base do
  include_context "formatter"

  describe "#call" do
    context "when event is not cancelled" do
      it "returns a formatted message" do
        expect(subject).to receive(:format_event).once.with(instance_of(LogStash::Event)).and_call_original
        expect(subject.call(severity, time, progname, message)).to be_a(LogStash::Event)
      end
    end

    context "when event is cancelled" do
      before(:each) do
        LogStashLogger.configure do |config|
          config.customize_event(&:cancel)
        end
      end

      it "returns `nil`" do
        expect(subject).not_to receive(:format_event)
        expect(subject.call(severity, time, progname, message)).to be_nil
      end
    end

    context "when exception is raised" do
      before do
        allow(subject).to receive(:error_logger).and_return(Logger.new('/dev/null'))
        allow(subject).to receive(:format_event).and_throw
      end

      it "logs an exception" do
        expect(subject).to receive(:log_error)
        subject.call(severity, time, progname, message)
      end

      it "retruns a failed to format message" do
        expect(subject.call(severity, time, progname, message)).to eq(LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_MSG)
      end
    end
  end

  describe '#force_utf8_encoding' do
    let(:event) { LogStash::Event.new("message" => "foo".force_encoding('ASCII-8BIT')) }

    it 'returns the same event' do
      expect(subject.send(:force_utf8_encoding, event)).to eq(event)
    end

    it 'forces the event message to UTF-8 encoding' do
      subject.send(:force_utf8_encoding, event)
      updated_event_data = event.instance_variable_get(:@data)
      expect(updated_event_data['message'].encoding.name).to eq('UTF-8')
    end
  end

  describe "#build_event" do
    let(:event) { formatted_message }

    describe "message type" do
      context "string" do
        it "puts the message into the message field" do
          expect(event['message']).to eq(message)
        end
      end

      context "JSON string" do
        let(:message) do
          { message: 'test', foo: 'bar' }.to_json
        end

        it "parses the JSON and merges into the event" do
          expect(event['message']).to eq('test')
          expect(event['foo']).to eq('bar')
        end
      end

      context "hash" do
        let(:message) do
          { 'message' => 'test', 'foo' => 'bar' }
        end

        it "merges into the event" do
          expect(event['message']).to eq('test')
          expect(event['foo']).to eq('bar')
        end
      end

      context "LogStash::Event" do
        let(:message) { LogStash::Event.new("message" => "foo") }

        it "returns a clone of the original event" do
          expect(event['message']).to eq("foo")
          expect(event).to_not equal(message)
        end
      end

      context "fallback" do
        let(:message) { [1, 2, 3] }

        it "calls inspect" do
          expect(event['message']).to eq(message.inspect)
        end
      end
    end

    describe "extra fields on the event" do
      it "adds severity" do
        expect(event['severity']).to eq(severity)
      end

      it "adds host" do
        expect(event['host']).to eq(hostname)
      end
    end

    describe "timestamp" do
      it "ensures time is in ISO8601 format" do
        expect(event.timestamp).to eq(time.iso8601(3))
      end
    end

    describe "long messages" do

      context "message field is present" do
        let(:message) { long_message }

        it "truncates long messages when max_message_size is set" do
          LogStashLogger.configure do |config|
            config.max_message_size = 2000
          end

          expect(event['message'].size).to eq(2000)
        end
      end

      context "event without message field" do
        let(:message) do
          { 'test_field' => 'test', 'foo' => 'bar' }
        end

        it "still works" do
          LogStashLogger.configure do |config|
            config.max_message_size = 2000
          end

          expect(event['message']).to eq(nil)
          expect(event['test_field']).to eq('test')
          expect(event['foo']).to eq('bar')
        end
      end
    end
  end
end
