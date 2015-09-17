require 'logstash-logger'

describe LogStashLogger::Formatter::Json do
  include_context "formatter"

  it "outputs in JSON format" do
    json_message = JSON.parse(formatted_message)
    expect(json_message["message"]).to eq(message)
  end
end
