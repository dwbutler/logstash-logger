require 'logstash-logger'

describe LogStashLogger do
  context "Syslog" do
    let(:program_name) { "MyApp" }
    let(:facility) { 128 } #Syslog::LOG_LOCAL0 }
    subject { LogStashLogger.new(type: :syslog, program_name: program_name, facility: facility) }
    let(:syslog) { subject.class.class_variable_get(:@@syslog) }

    it { is_expected.to be_a Syslog::Logger }

    it "writes formatted messages to syslog" do
      expect(syslog).to receive(:log)
      subject.info("test")
    end

    it "sets the syslog identity" do
      expect(syslog.ident).to eq(program_name)
    end

    it "sets the default facility if supported" do
      expect(subject.facility).to eq(facility) if subject.respond_to?(:facility)
    end
  end
end
