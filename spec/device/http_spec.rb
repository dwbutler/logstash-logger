require 'logstash-logger'

describe LogStashLogger::Device::HTTP do
  include_context 'device'

  it "Post event to HTTP" do
    expect(Net::HTTP).to receive(:post)
    http_device.write('test')
  end

  describe "body format" do
    let(:url) { 'http://localhost' }
    let(:messages) { ["{\"a\":1}\n", "{\"b\":2}"] }

    it "sends a JSON array by default" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true)
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "[{\"a\":1}\n,{\"b\":2}]", anything)
      device.write_batch(messages)
    end

    it "sends newline-delimited JSON when ndjson is enabled" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, ndjson: true)
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "{\"a\":1}\n{\"b\":2}\n", anything)
      device.write_batch(messages)
    end
  end

end
