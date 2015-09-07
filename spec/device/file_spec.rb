require 'logstash-logger'

describe LogStashLogger::Device::File do
  include_context 'device'

  it "writes to a file" do
    expect(file_device.to_io).to be_a ::File
  end

  context "when path is not specified" do
    it "raises an exception" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end
end
