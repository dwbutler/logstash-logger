require 'logstash-logger'

describe LogStashLogger::Device::Stdout do
  it "writes to $stdout" do
    expect(subject.to_io).to eq($stdout)
    expect($stdout).to receive(:write).once
    subject.write("test")
  end

  it "ignores #close" do
    expect($stdout).not_to receive(:close)
    subject.close
  end
end
