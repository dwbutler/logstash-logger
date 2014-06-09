require 'logstash-logger'

describe LogStashLogger::Connection do
  include_context 'logger'

  it "defaults host to 0.0.0.0" do
    expect(connection.host).to eq("0.0.0.0")
  end

  it "defaults type to :udp" do
    expect(connection.type).to eq(:udp)
  end

  context "when port is not specified" do
    it "raises an exception" do
      expect { described_class.new }.to raise_error
    end
  end
end
