require 'logstash-logger'

describe LogStashLogger::Device::Unix do
  include_context 'device'

  let(:unix_socket) { double("UNIXSocket") }

  before(:each) do
    allow(::UNIXSocket).to receive(:new) { unix_socket }
    allow(unix_socket).to receive(:sync=)
  end

  it "writes to a local unix socket" do
    expect(unix_socket).to receive(:write)
    unix_device.write('foo')
  end

  context "when path is not specified" do
    it "raises an exception" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end
end
