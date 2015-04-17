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

  describe "initializer" do
    let(:redis_options) { { host: HOST, port: 6379 } }
    subject { LogStashLogger::Device::Redis.new(redis_options).connect }

    context "path is not blank" do
      before do
        redis_options[:path] = "/0"
      end

      it "sets the db" do
        expect(Redis).to receive(:new).with(hash_including(db: 0))
        subject
      end

    end

    context "path is blank" do
      before do
        redis_options[:path] = ""
      end

      it "does not set the db" do
        expect(Redis).to receive(:new).with(hash_excluding(:db))
        subject
      end
    end

  end

end
