require 'logstash-logger'

describe LogStashLogger::Device::Balancer do
  include_context 'device'

  # Create a Balancer writing to both STDOUT and a StringIO
  subject { balancer_device }

  describe '#write' do
    before do
      allow(subject.devices).to receive(:sample) { io }
    end

    it "writes to one device" do
      expect(io).to receive(:write).once
      expect($stdout).to_not receive(:write)
      subject.write("log message")
    end
  end

  describe '#flush, #close' do
    [:flush, :close].each do |method_name|
      it "call on all devices" do
        subject.devices.each do |device|
          expect(device).to receive(method_name).once
        end
        subject.send(method_name)
      end
    end
  end
end
