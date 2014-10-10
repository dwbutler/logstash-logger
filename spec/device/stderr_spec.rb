require 'logstash-logger'

describe LogStashLogger::Device::Stderr do
  let(:stderr) { $stderr }

  it 'writes to stderr' do
    expect(subject.to_io).to eq stderr
    expect(stderr).to receive(:write).once
    subject.write("test")
  end

  it 'ignores #close' do
    expect(stderr).not_to receive(:close)
    subject.close
  end
end
