require 'logstash-logger'

describe LogStashLogger::Device::MultiDelegator do
  include_context 'device'

  # Create a MultiDelegator writing to both STDOUT and a StringIO
  let(:subject) { multi_delegator_device }

  let(:stdout) { $stdout }
  let(:io) { StringIO.new }

  it "writes to $stdout" do
    # MultiDelegator writes to stdout
    expect(stdout).to receive(:write).once

    # MultiDelegator writes to IO
    expect(io).to receive(:write).once

    subject.write("test")
  end
end
