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

describe LogStashLogger::Device::Connectable, 'max_record_bytes' do
  let(:error_log) { StringIO.new }

  def device(**opts)
    LogStashLogger::Device.new({ type: :udp, port: 5228, sync: false, buffer_max_interval: 3600,
                                 buffer_flush_at_exit: false, error_logger: ::Logger.new(error_log) }.merge(opts))
  end

  def pending(dev)
    dev.instance_variable_get(:@buffer_state)[:pending_items][nil]
  end

  it 'is off by default' do
    dev = device
    dev.write('x' * 2_000_000)
    expect(pending(dev).size).to eq(1)
  end

  it 'drops only records over the limit, logging the size but not the content' do
    dev = device(max_record_bytes: 100)
    dev.write('small')
    dev.write('secret' * 50)
    expect(pending(dev)).to eq(['small'])
    expect(error_log.string).to include('dropping a record of 300 bytes: over max_record_bytes (100)')
    expect(error_log.string).not_to include('secret')
  end

  it 'measures records that are not Strings' do
    dev = device(max_record_bytes: 2)
    dev.write(123)
    expect(pending(dev)).to be_empty
  end

  it 'accepts a String value, as URI query options arrive' do
    dev = LogStashLogger::Device.new(uri: 'udp://localhost:5228?max_record_bytes=100', buffer_flush_at_exit: false,
                                     error_logger: ::Logger.new(error_log))
    dev.write('x' * 101)
    expect(pending(dev)).to be_empty
  end

  it 'rejects a value that is not a positive number' do
    expect { device(max_record_bytes: 'lots') }.to raise_error(ArgumentError)
    expect { device(max_record_bytes: 0) }.to raise_error(ArgumentError, /positive/)
  end

  it 'is not forwarded to the Redis client' do
    expect(::Redis).to receive(:new).with(hash_excluding(:max_record_bytes)).and_return(double('redis'))
    LogStashLogger::Device.new(type: :redis, max_record_bytes: 100, buffer_flush_at_exit: false).connect
  end
end
