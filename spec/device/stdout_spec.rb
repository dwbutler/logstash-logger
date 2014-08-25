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

  context "when io is passed in" do
    let(:io) { StringIO.new }
    subject { described_class.new(io: io) }

    it "accepts an optional io object to write to" do
      expect(subject.to_io).to eq(io)
      expect{ subject.write("test") }.to change { io.string }.from('').to('test')
    end
  end
end
