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

  describe "content type" do
    let(:url) { 'http://localhost' }

    def expect_content_type(type)
      expect(Net::HTTP).to receive(:post)
        .with(anything, anything, {"Content-Type" => type})
    end

    it "is application/json by default" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true)
      expect_content_type("application/json")
      device.write_batch(["{}"])
    end

    it "is application/x-ndjson when ndjson is enabled" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, ndjson: true)
      expect_content_type("application/x-ndjson")
      device.write_batch(["{}"])
    end

    it "can be overridden with content_type" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, ndjson: true, content_type: "application/json")
      expect_content_type("application/json")
      device.write_batch(["{}"])
    end
  end

end
