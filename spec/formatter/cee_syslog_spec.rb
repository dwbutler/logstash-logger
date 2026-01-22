require 'logstash-logger'

describe LogStashLogger::Formatter::CeeSyslog do
  include_context "formatter"

  describe "#call" do
    let(:facility) { "facility" }

    before do
      allow(subject).to receive(:build_facility).and_return(facility)
    end

    it "outputs a facility before the @cee" do
      expect(formatted_message).to match(/\A#{facility}:@cee:/)
    end

    it "serializes the LogStash::Event data as JSON" do
      json_data = formatted_message[/\A#{facility}:@cee:\s?(.*)\Z/, 1]
      json_message = JSON.parse(json_data)
      expect(json_message["message"]).to eq(message)
    end
  end

  describe "#build_facility" do
    let(:host) { { 'hostname' => Socket.gethostname } }

    before do
      formatted_message
    end

    it "includes hostname and progname" do
      expect(subject.send(:build_facility, host)).to match(/\A#{host['hostname']}\s#{progname}\z/)
    end

    context "without progname" do
      let(:progname) { nil }

      it "only includes hostname" do
        expect(subject.send(:build_facility, host)).to match(/\A#{host['hostname']}\z/)
      end
    end
  end
end
