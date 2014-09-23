require 'logstash-logger'

describe LogStashLogger::Device do
  include_context 'device'

  context "when port is specified" do
    it "defaults type to UDP" do
      expect(device_with_port).to be_a LogStashLogger::Device::UDP
    end
  end

  context "when passing in configuration" do
    let(:configuration) { {type: :udp, port: port} }

    subject(:new_device) { described_class.new(configuration) }

    it "does not mutate the passed configuration" do
      expect{ new_device }.to_not change { configuration }
      expect( new_device ).to be_a LogStashLogger::Device::UDP
    end
  end

  context "when configuration type is a String" do
    let(:configuration) { {type: "udp", port: port} }

    subject(:new_device) { described_class.new(configuration) }

    it "it correctly recognizes the device type" do
      expect(new_device).to be_a LogStashLogger::Device::UDP
    end
  end

  describe ".parse_uri_config" do
    subject(:parse_uri_config) { described_class.parse_uri_config(uri) }

    context "when uri is valid" do
      let(:uri) { 'udp://localhost:5228' }

      it { is_expected.to eq({type: 'udp', host: 'localhost', port: 5228, path: ''}) }
    end

    context "when uri is invalid" do
      let(:uri) { "I'm not a parsable uri" }
      it { is_expected.to be nil }
      specify { expect{ parse_uri_config }.to_not raise_error }
    end
  end

  describe "Parsing URI configurations" do
    subject(:new_device) { described_class.new(uri_config) }

    context "when URI config is udp" do
      let(:uri_config) { 'udp://localhost:5228' }
      it { is_expected.to be_a LogStashLogger::Device::UDP }
    end

    context "when URI config is tcp" do
      let(:uri_config) { 'tcp://localhost:5229' }
      it { is_expected.to be_a LogStashLogger::Device::TCP }
    end

    context "when URI config is unix" do
      let(:uri_config) { 'unix:///some/path/to/socket' }
      it { is_expected.to be_a LogStashLogger::Device::Unix }
    end

    context "when URI config is file" do
      let(:uri_config) { "file://#{file.path}" }
      it { is_expected.to be_a LogStashLogger::Device::File }
    end

    context "when URI config is redis" do
      let(:uri_config) { "redis://localhost:9999" }
      it { is_expected.to be_a LogStashLogger::Device::Redis }
    end

    context "when URI config is stdout" do
      let(:uri_config) { "stdout://localhost" }
      it { is_expected.to be_a LogStashLogger::Device::Stdout }
    end
  end

end
