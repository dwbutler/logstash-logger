require 'logstash-logger'

describe LogStashLogger::Device::Connectable do
  include_context 'device'

  let(:io) { double("IO") }

  subject { udp_device }

  describe "#reconnect" do
    context "with active IO connection" do
      before do
        subject.instance_variable_set(:@io, io)
      end

      it "closes the connection" do
        expect(io).to receive(:close).once
        subject.reconnect
      end
    end

    context "with no active IO connection" do
      before do
        subject.instance_variable_set(:@io, nil)
      end

      it "does nothing" do
        expect(io).to_not receive(:close)
        subject.reconnect
      end
    end
  end

  describe "#with_connection" do
    context "on exception" do
      before do
        allow(subject).to receive(:connected?) { raise(StandardError) }
        allow(subject).to receive(:warn)
      end

      context "with active IO connection" do
        before do
          subject.instance_variable_set(:@io, io)
        end

        it "closes the connection" do
          expect(io).to receive(:close).once

          expect {
            subject.with_connection do |connection|
              connection
            end
          }.to raise_error(StandardError)
        end
      end

      context "with no active IO connection" do
        before do
          subject.instance_variable_set(:@io, nil)
        end

        it "does nothing" do
          expect(io).to_not receive(:close)

          expect {
            subject.with_connection do |connection|
              connection
            end
          }.to raise_error(StandardError)
        end
      end
    end
  end
end
