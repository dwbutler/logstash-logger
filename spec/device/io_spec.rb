require 'logstash-logger'

describe LogStashLogger::Device::IO do
  include_context 'device'

  subject { io_device }

  it "writes to the IO object" do
    expect(subject.to_io).to eq(io)
    expect(io).to receive(:write).once
    subject.write("test")
  end
end
