require 'logstash-logger'

describe LogStashLogger::Formatter::Json do
  include_context "formatter"

  it "outputs in JSON format" do
    json_message = JSON.parse(formatted_message)
    expect(json_message["message"]).to eq(message)
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

  context "timestamp ordering" do
    let(:message) { { message: 'test', foo: 'bar' } }

    it "places @timestamp first in JSON output" do
      timestamp_index = formatted_message.index('"@timestamp"')
      message_index = formatted_message.index('"message"')

      expect(timestamp_index).not_to be_nil
      expect(message_index).not_to be_nil
      expect(timestamp_index).to be < message_index
    end
  end

  context "key ordering" do
    let(:message) { { foo: 'bar', baz: 'qux' } }

    it "preserves custom field order in JSON output" do
      foo_index = formatted_message.index('"foo"')
      baz_index = formatted_message.index('"baz"')

      expect(foo_index).not_to be_nil
      expect(baz_index).not_to be_nil
      expect(foo_index).to be < baz_index
    end
  end
end
