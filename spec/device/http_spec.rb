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
        .and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
      device.write_batch(messages)
    end

    it "sends a JSON array with format: :json_array" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :json_array)
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "[{\"a\":1}\n,{\"b\":2}]", anything)
        .and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
      device.write_batch(messages)
    end

    it "sends newline-delimited JSON with format: :ndjson" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: :ndjson)
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "{\"a\":1}\n{\"b\":2}\n", anything)
        .and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
      device.write_batch(messages)
    end

    it "accepts the format as a string" do
      device = LogStashLogger::Device.new(type: :http, url: url, sync: true, format: "ndjson")
      expect(Net::HTTP).to receive(:post)
        .with(URI(url), "{\"a\":1}\n{\"b\":2}\n", anything)
        .and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
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
        .and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
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

describe LogStashLogger::Device::HTTP, 'records the collector rejects' do
  let(:url) { 'http://localhost' }
  let(:error_log) { StringIO.new }
  let(:sent) { [] }
  let(:small) { (1..5).map { |i| %({"n":#{i}}) } }

  def device(**opts)
    LogStashLogger::Device.new({ type: :http, url: url, sync: false, buffer_max_interval: 3600,
                                 buffer_flush_at_exit: false, error_logger: ::Logger.new(error_log) }.merge(opts))
  end

  # Stubs the HTTP endpoint: any request containing a "BAD" record gets the
  # given error status, and every other request succeeds and is recorded.
  def stub_endpoint_rejecting_bad_records(status:, message:)
    allow(Net::HTTP).to receive(:post) do |_url, body, _headers|
      if body.include?('BAD')
        klass = Net::HTTPResponse::CODE_TO_OBJ[status]
        klass.new('1.1', status, message)
      else
        sent << body
        Net::HTTPOK.new('1.1', '200', 'OK')
      end
    end
  end

  it 'delivers the other records and drops only the rejected one' do
    stub_endpoint_rejecting_bad_records(status: '413', message: 'Payload Too Large')
    device.write_batch(small + ['"BAD"'])
    expect(sent).to eq(small.map { |m| "[#{m}]" })
    expect(error_log.string).to include('dropping a record of 5 bytes that the collector rejected: HTTP 413')
  end

  it 'drops a rejected single-record batch without raising' do
    stub_endpoint_rejecting_bad_records(status: '400', message: 'Bad Request')
    expect { device.write_batch(['"BAD"']) }.not_to raise_error
    expect(error_log.string).to include('HTTP 400')
  end

  it 'clears a buffered batch instead of retrying the rejected record forever' do
    stub_endpoint_rejecting_bad_records(status: '422', message: 'Unprocessable Entity')
    dev = device
    small.each { |m| dev.write(m) }
    dev.write('"BAD"')
    dev.buffer_flush(force: true)
    expect(dev.instance_variable_get(:@buffer_state)[:pending_count]).to eq(0)
    expect(sent.size).to eq(small.size)
  end

  # Errors that do not depend on the records, so the batch is retried
  {
    '401' => 'Unauthorized',          # missing or wrong credentials
    '403' => 'Forbidden',             # credentials not allowed
    '404' => 'Not Found',             # wrong URL, or the collector is not deployed yet
    '429' => 'Too Many Requests',     # rate limited
    '500' => 'Internal Server Error', # collector error
    '503' => 'Service Unavailable',   # collector down or restarting
  }.each do |status, message|
    it "retries the whole batch on HTTP #{status} #{message}" do
      stub_endpoint_rejecting_bad_records(status: status, message: message)
      expect { device.write_batch(['"BAD"', 'ok']) }.to raise_error(RuntimeError, /HTTP log upload failed: #{status}/)
      expect(error_log.string).to include("HTTP log upload failed: #{status}")
    end
  end

  it 'raises if a record sent on its own hits a retryable error' do
    calls = 0
    allow(Net::HTTP).to receive(:post) do
      calls += 1
      calls == 1 ? Net::HTTPRequestEntityTooLarge.new('1.1', '413', 'Too Large') : Net::HTTPServiceUnavailable.new('1.1', '503', 'Unavailable')
    end
    expect { device.write_batch(['a', 'b']) }.to raise_error(RuntimeError, /503/)
  end

  it 'sends records that are not Strings as text' do
    allow(Net::HTTP).to receive(:post) { |_u, body, _h| sent << body; Net::HTTPOK.new('1.1', '200', 'OK') }
    device(format: :ndjson).write_batch([123, '{"a":1}'])
    expect(sent).to eq(["123\n{\"a\":1}\n"])
  end
end
