require 'logstash-logger'

describe LogStashLogger::Device::Stdout do
  let(:stdout) { $stdout }

  it "writes to $stdout" do
    expect(subject.to_io).to eq(stdout)
    expect(stdout).to receive(:write).once
    subject.write("test")
  end

  it "ignores #close" do
    expect(stdout).not_to receive(:close)
    subject.close
  end

  context "when the default $stdout has been overridden" do
    before { $stdout = StringIO.new }
    after  { $stdout = STDOUT }

    let(:injected_stdout) { STDOUT }

    subject { described_class.new(io: injected_stdout) }

    it "accepts an injectable reference to stdout" do
      expect(subject.to_io).to eq(injected_stdout)
      expect(injected_stdout).to receive(:write).once
      subject.write("test")
    end
  end
end
