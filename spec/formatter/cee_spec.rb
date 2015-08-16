require 'logstash-logger'

describe LogStashLogger::Formatter::Cee do
  include_context "formatter"

  it "outputs in CEE format" do
    expect(formatted_message).to match(/\A@cee:/)
  end

  it "serializes the LogStash::Event data as JSON" do
    json_data = formatted_message[/\A@cee:\s?(.*)\z/, 1]
    json_message = JSON.parse(json_data)
    expect(json_message["message"]).to eq(message)
  end
end
