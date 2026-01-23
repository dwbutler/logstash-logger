require 'logstash-logger'

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
end
