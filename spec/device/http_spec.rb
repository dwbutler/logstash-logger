require 'logstash-logger'

describe LogStashLogger::Device::HTTP do
  include_context 'device'

  it "Post event to HTTP" do
    expect(Net::HTTP).to receive(:post).and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
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

    it "sends a JSON array with format: :json_array" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :json_array)
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "[{\"a\":1}\n,{\"b\":2}]", anything)
      device.write_batch(messages)
    end

    it "sends newline-delimited JSON with format: :ndjson" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :ndjson)
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "{\"a\":1}\n{\"b\":2}\n", anything)
      device.write_batch(messages)
    end

    it "accepts the format as a string" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: "ndjson")
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "{\"a\":1}\n{\"b\":2}\n", anything)
      device.write_batch(messages)
    end

    it "raises an error for an unknown format" do
      expect {
        LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :xml)
      }.to raise_error(ArgumentError, /Unknown HTTP body format: :xml/)
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

    it "is application/x-ndjson for format: :ndjson" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :ndjson)
      expect_content_type("application/x-ndjson")
      device.write_batch(["{}"])
    end

    it "can be overridden with content_type" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :ndjson, content_type: "application/json")
      expect_content_type("application/json")
      device.write_batch(["{}"])
    end
  end

  it "does not raise on a successful response" do
    allow(Net::HTTP).to receive(:post).and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
    expect { http_device.write_batch(['test']) }.not_to raise_error
  end

  it "raises on an error response" do
    allow(Net::HTTP).to receive(:post).and_return(Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error'))
    expect { http_device.write_batch(['test']) }.to raise_error(RuntimeError, "HTTP log upload failed: 500 Internal Server Error")
  end

  it "raises on a client error response" do
    allow(Net::HTTP).to receive(:post).and_return(Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized'))
    expect { http_device.write_batch(['test']) }.to raise_error(RuntimeError, /401 Unauthorized/)
  end
end
