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

    context "when building the event raises" do
      before do
        allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
        allow(subject).to receive(:build_event).and_raise(ArgumentError, 'boom')
      end

      it "logs an exception" do
        expect(subject).to receive(:log_error).and_call_original
        subject.call(severity, time, progname, message)
      end

      it "returns a well-formed placeholder event instead of a bare string" do
        event = subject.call(severity, time, progname, message)
        expect(event).to be_a(LogStash::Event)
        expect(event['message']).to eq(LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_MSG)
        expect(event['tags']).to eq([LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_TAG])
        expect(event['error']).to eq('ArgumentError')
        expect(event['severity']).to eq(severity)
        expect(event['@timestamp']).to eq(time.iso8601(3))
      end
    end

    context "when even the placeholder cannot be formatted" do
      before do
        allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
        allow(subject).to receive(:format_event).and_raise(ArgumentError, 'boom')
      end

      it "returns nil, which devices drop" do
        expect(subject.call(severity, time, progname, message)).to be_nil
      end
    end

    context "when logged content carries an @timestamp that is not a time" do
      let(:message) { '{"message":"hello","@timestamp":"not-a-time"}' }

      it "keeps the logger time and formats the record normally" do
        event = subject.call(severity, time, progname, message)
        expect(event['message']).to eq('hello')
        expect(event['@timestamp']).to eq(time.iso8601(3))
      end
    end

    context "when logged content carries a valid @timestamp and @version" do
      let(:message) { '{"message":"hello","@timestamp":"2001-01-01T00:00:00Z","@version":"9"}' }

      it "uses the logger time and version and keeps the logged values aside" do
        event = subject.call(severity, time, progname, message)
        expect(event['@timestamp']).to eq(time.iso8601(3))
        expect(event['@version']).to eq('1')
        expect(event['message_fields']).to eq('@timestamp' => '2001-01-01T00:00:00Z', '@version' => '9')
      end

      it "does the same for a Hash message with Symbol keys" do
        event = subject.call(severity, time, progname, { message: 'hello', :@timestamp => 12345, :@version => '9' })
        expect(event['@timestamp']).to eq(time.iso8601(3))
        expect(event['@version']).to eq('1')
        expect(event['message_fields']).to eq('@timestamp' => 12345, '@version' => '9')
      end

      context "when trust_message_fields is set" do
        before { LogStashLogger.configure { |config| config.trust_message_fields = true } }

        it "keeps them" do
          event = subject.call(severity, time, progname, message)
          expect(event['@timestamp']).to start_with('2001-01-01T00:00:00')
          expect(event['@version']).to eq('9')
        end
      end
    end
  end

  describe '#force_utf8_encoding' do
    let(:message) { "foo x\xc3x".force_encoding('ASCII-8BIT').freeze }
    let(:event) { LogStash::Event.new("message" => message) }

    it 'returns the same event' do
      expect(subject.send(:force_utf8_encoding, event)).to eq(event)
    end

    it 'forces the event message to UTF-8 encoding' do
      subject.send(:force_utf8_encoding, event)
      updated_event_data = event.instance_variable_get(:@data)
      expect(updated_event_data['message'].encoding.name).to eq('UTF-8')
    end

    context 'frozen message string' do
      let(:message) { "foo x\xc3x".dup.force_encoding('ASCII-8BIT').freeze }

      it 'returns the same event' do
        expect(subject.send(:force_utf8_encoding, event)).to eq(event)
      end

      it 'forces the event message to UTF-8 encoding' do
        subject.send(:force_utf8_encoding, event)
        updated_event_data = event.instance_variable_get(:@data)
        expect(updated_event_data['message'].encoding.name).to eq('UTF-8')
      end
    end
  end

  describe '#force_utf8_encoding with invalid bytes outside the message' do
    let(:event) do
      LogStash::Event.new(
        'message' => 'ok',
        'tags' => ["evil-\xFF".b],
        'user' => { 'agent' => "x\xFFy".dup.force_encoding(Encoding::UTF_8) },
        "k\xFF".b => 'v'
      )
    end

    it 'repairs every String in the event, nested ones and keys included' do
      subject.send(:force_utf8_encoding, event)
      data = event.to_hash

      expect(data['message']).to eq('ok')
      expect(data['tags']).to eq(["evil-\uFFFD"])
      expect(data['user']).to eq('agent' => "x\uFFFDy")
      expect(data["k\uFFFD"]).to eq('v')
      expect(JSON.parse(event.to_json)['tags']).to eq(["evil-\uFFFD"])
    end

    it 'keeps both values when two keys repair to the same String' do
      event = LogStash::Event.new('message' => 'ok', 'fields' => { "a\xFF".b => 1, "a\xFE".b => 2 })

      subject.send(:force_utf8_encoding, event)
      expect(event.to_hash['fields']).to eq("a\uFFFD" => 1, "a\uFFFD_2" => 2)
    end

    it 'repairs a Hash that contains itself without recursing forever' do
      cyclic = { 'agent' => "x\xFF".b }
      cyclic['self'] = cyclic
      event = LogStash::Event.new('message' => 'ok', 'fields' => cyclic)

      subject.send(:force_utf8_encoding, event)
      fields = event.to_hash['fields']
      expect(fields['agent']).to eq("x\uFFFD")
      expect(fields['self']).to equal(fields)
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

        it "keeps values that cannot be cloned" do
          worker = Thread.current
          event = subject.call(severity, time, progname, LogStash::Event.new('message' => 'foo', 'worker' => worker))
          expect(event['message']).to eq('foo')
          expect(event['worker']).to equal(worker)
        end

        it "leaves the caller's tags unchanged" do
          logged = LogStash::Event.new('message' => 'foo', 'tags' => ['e'])
          event = subject.tagged('t') { subject.call(severity, time, progname, logged) }
          expect(event['tags']).to eq(%w[e t])
          expect(logged['tags']).to eq(['e'])
        end

        it "keeps a subclass whose constructor takes other arguments" do
          klass = Class.new(LogStash::Event) do
            attr_reader :origin

            def initialize(data, origin)
              super(data)
              @origin = origin
            end
          end
          logged = klass.new({ 'message' => 'foo' }, 'importer')
          event = subject.call(severity, time, progname, logged)

          expect(event).to be_a(klass)
          expect(event).to_not equal(logged)
          expect(event.origin).to eq('importer')
          expect(event['message']).to eq('foo')
        end

        it "is not written when it was cancelled" do
          logged = LogStash::Event.new('message' => 'foo')
          logged.cancel
          expect(subject.call(severity, time, progname, logged)).to be_nil
        end
      end

      context "fallback" do
        let(:message) { [1, 2, 3] }

        it "calls inspect" do
          expect(event['message']).to eq(message.inspect)
        end
      end
    end

    describe "tags from a Hash message" do
      let(:fields) { { message: 'job', tags: ['worker'] } }

      before do
        allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
      end

      it "gives each record its own tags and leaves the caller's Hash unchanged" do
        first = subject.tagged('req-1') { subject.call(severity, time, progname, fields) }
        second = subject.tagged('req-2') { subject.call(severity, time, progname, fields) }
        untagged = subject.call(severity, time, progname, fields)

        expect(first['tags']).to eq(%w[worker req-1])
        expect(second['tags']).to eq(%w[worker req-2])
        expect(untagged['tags']).to eq(%w[worker])
        expect(fields[:tags]).to eq(%w[worker])
      end

      it "formats a record whose tags Array is frozen" do
        frozen = { message: 'job', tags: ['worker'].freeze }
        event = subject.tagged('req-1') { subject.call(severity, time, progname, frozen) }

        expect(event['message']).to eq('job')
        expect(event['tags']).to eq(%w[worker req-1])
      end

      it "keeps a single tag value as an element of the tags Array" do
        single = { message: 'job', tags: 'worker'.dup.freeze }
        event = subject.tagged('req-1') { subject.call(severity, time, progname, single) }

        expect(event['message']).to eq('job')
        expect(event['tags']).to eq(%w[worker req-1])
        expect(single[:tags]).to eq('worker')
      end

      it "does the same for a JSON message" do
        event = subject.tagged('req-1') { subject.call(severity, time, progname, '{"message":"job","tags":"worker"}') }
        expect(event['tags']).to eq(%w[worker req-1])
      end
    end

    describe "fields the log call sets" do
      let(:severity) { 'ERROR' }

      [
        '{"message":"m","severity":"DEBUG"}',
        { 'message' => 'm', 'severity' => 'DEBUG' },
        { message: 'm', severity: 'DEBUG' }
      ].each do |logged|
        it "uses the call-site severity for #{logged.inspect} and keeps the logged value aside" do
          event = subject.call(severity, time, progname, logged)
          expect(event['severity']).to eq('ERROR')
          expect(event['message']).to eq('m')
          expect(event['message_fields']).to eq('severity' => 'DEBUG')
        end
      end

      it "merges the logged value into the message's own message_fields Hash, whose keys win" do
        logged = { 'message' => 'm', 'severity' => 'DEBUG', 'message_fields' => { 'a' => 1, severity: 'own' } }
        event = subject.call(severity, time, progname, logged)
        expect(event['message_fields']).to eq('a' => 1, 'severity' => 'own')
        expect(logged['message_fields']).to eq('a' => 1, severity: 'own')
      end

      it "keeps a message_fields value that is not a Hash under its own name" do
        event = subject.call(severity, time, progname, '{"message":"m","severity":"DEBUG","message_fields":"x"}')
        expect(event['message_fields']).to eq('severity' => 'DEBUG', 'message_fields' => 'x')
      end

      context "when trust_message_fields is set" do
        before { LogStashLogger.configure { |config| config.trust_message_fields = true } }

        it "keeps the logged severity" do
          event = subject.call(severity, time, progname, '{"message":"m","severity":"DEBUG"}')
          expect(event['severity']).to eq('DEBUG')
          expect(event['message_fields']).to be_nil
        end
      end
    end

    describe "extra fields on the event" do
      it "adds severity" do
        expect(event['severity']).to eq(severity)
      end

      it "adds host" do
        expect(event['host']['hostname']).to eq(hostname)
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
