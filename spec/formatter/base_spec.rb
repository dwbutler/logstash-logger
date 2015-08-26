require 'logstash-logger'

describe LogStashLogger::Formatter::Base do
  include_context "formatter"

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
  end
end
