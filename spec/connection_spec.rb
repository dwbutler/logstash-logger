require 'logstash-logger'

describe LogStash::Connection do
  include_context 'logger'

  it "defaults host to 0.0.0.0" do
    expect(connection.host).to eq("0.0.0.0")
  end

  it "defaults type to :udp" do
    expect(connection.type).to eq(:udp)
  end

end