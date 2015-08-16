require 'logstash-logger'

describe LogStashLogger::Formatter::LogStashEvent do
  include_context "formatter"

  it "outputs a LogStash::Event" do
    expect(formatted_message).to be_a LogStash::Event
    expect(formatted_message["message"]).to eq(message)
  end
end
