require 'logstash-logger'

describe LogStashLogger::Device::MultiDelegator do
  include_context 'device'

  # Create a MultiDelegator writing to both STDOUT and a StringIO
  subject { multi_delegator_device }

  it "writes to all outputs" do
    expect($stdout).to receive(:write).once
    expect(io).to receive(:write).once

    subject.write("test")
  end
end
