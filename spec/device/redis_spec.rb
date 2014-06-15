require 'logstash-logger'
require 'redis'

describe LogStashLogger::Device::Redis do
  include_context 'device'

  let(:redis) { double("Redis") }

  before(:each) do
    allow(Redis).to receive(:new) { redis }
    allow(redis).to receive(:connect)
  end

  it "writes to a Redis list" do
    expect(redis).to receive(:rpush)
    redis_device.write "foo"
  end

  it "defaults the Redis list to 'logstash'" do
    expect(redis_device.list).to eq('logstash')
  end
end
