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
end
