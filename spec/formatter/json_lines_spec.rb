require 'logstash-logger'
require_relative '../support/unserializable_value'

describe LogStashLogger::Formatter::JsonLines do
  include_context "formatter"

  it "outputs in JSON format" do
    json_message = JSON.parse(formatted_message)
    expect(json_message["message"]).to eq(message)
  end

  it "terminates with a line break" do
    expect(formatted_message[-1]).to eq("\n")
  end

  context 'encoding error is raised' do
    let(:message) { "foo x\xc3x".force_encoding('ASCII-8BIT') }

    before do
      allow(subject).to receive(:error_logger).and_return(Logger.new('/dev/null'))
    end

    it 'logs the error' do
      expect(subject).to receive(:log_error)
      formatted_message
    end

    it 'forces the message encoding to utf8' do
      expect(subject).to receive(:force_utf8_encoding)
      formatted_message
    end

    it "outputs in JSON format with message encoding updated to utf8" do
      json_message = JSON.parse(formatted_message)
      expect(json_message["message"]).to eq(message.force_encoding(Encoding::UTF_8).scrub)
    end
  end

  context 'when a tag or another field has invalid bytes' do
    before do
      allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
    end

    it 'writes the record with every String repaired' do
      fields = { 'message' => 'hello', 'agent' => "x\xFFy".b, 'nested' => { 'a' => "z\xFF".b } }
      output = subject.tagged("evil-\xFF".b, "caf\xC3\xA9".b) do
        subject.call(severity, time, progname, fields)
      end

      expect(output.count("\n")).to eq(1)
      data = JSON.parse(output)
      expect(data['message']).to eq('hello')
      expect(data['tags']).to eq(["evil-\uFFFD", "caf\u00E9"])
      expect(data['agent']).to eq("x\uFFFDy")
      expect(data['nested']).to eq('a' => "z\uFFFD")
    end
  end

  context 'when a logged Hash contains itself' do
    let(:message) { {}.tap { |data| data['self'] = data } }

    before do
      allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
    end

    it 'writes the placeholder record instead of raising' do
      data = JSON.parse(formatted_message)
      expect(data['tags']).to eq([LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_TAG])
      expect(data['error']).to eq('JSON::NestingError')
    end
  end

  context 'when a message uses Symbol keys for fields the logger also sets' do
    # Rejects a record whose JSON object has two members with the same name
    def parse_strictly(line)
      JSON.parse(line, allow_duplicate_key: false)
    end

    before do
      allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
    end

    {
      'host' => 'web-2',
      'severity' => 'custom',
      '@version' => '2',
      '@timestamp' => '2001-01-01T00:00:00Z'
    }.each do |name, value|
      it "writes one #{name} member with the value of the String key" do
        line = subject.call(severity, time, progname, { message: 'm', name.to_sym => value })
        string_keyed = subject.call(severity, time, progname, { 'message' => 'm', name => value })

        expect(parse_strictly(line)['message']).to eq('m')
        expect(parse_strictly(line)[name]).to eq(parse_strictly(string_keyed)[name])
      end
    end

    it 'writes one tags and one host member for a tagged LogStash::Event' do
      event = LogStash::Event.new(message: 'm', tags: ['caller'], host: 'web-2')
      line = subject.tagged('req-1') { subject.call(severity, time, progname, event) }

      expect(parse_strictly(line)['tags']).to eq(%w[caller req-1])
      expect(parse_strictly(line)['host']).to eq('web-2')
    end
  end

  context 'when the record cannot be serialized' do
    let(:message) { { 'message' => 'x', 'n' => UnserializableValue.new } }

    before do
      allow(subject).to receive(:error_logger).and_return(Logger.new(IO::NULL))
    end

    it 'emits a JSON placeholder line instead of a bare string' do
      expect(formatted_message).to end_with("\n")
      expect(formatted_message.count("\n")).to eq(1)
      data = JSON.parse(formatted_message)
      expect(data['message']).to eq(LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_MSG)
      expect(data['tags']).to eq([LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_TAG])
      expect(data['error']).to eq('JSON::GeneratorError')
    end
  end
end
