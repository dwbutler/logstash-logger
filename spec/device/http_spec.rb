require 'logstash-logger'

describe LogStashLogger::Device::HTTP do
  include_context 'device'

  it "Post event to HTTP" do
    expect(Net::HTTP).to receive(:post).and_return(Net::HTTPOK.new('1.1', '200', 'OK'))
    http_device.write('test')
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
