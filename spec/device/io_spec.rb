require 'logstash-logger'

describe LogStashLogger::Device::IO do
  include_context 'device'

  subject { io_device }

  it "writes to the IO object" do
    expect(subject.to_io).to eq(io)
    expect(io).to receive(:write).once
    subject.write("test")
  end

  it "leaves the IO open and writable on #reset" do
    subject.reset

    expect(io).not_to be_closed
    subject.write("test")
    expect(io.string).to eq("test")
  end
end
