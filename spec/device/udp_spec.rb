require 'logstash-logger'

describe LogStashLogger::Device::UDP do
  include_context 'device'

  it "writes to a UDP socket" do
    expect(udp_device.to_io).to be_a UDPSocket
  end

  describe "records larger than one datagram" do
    let(:error_log) { StringIO.new }
    let(:receiver) { UDPSocket.new.tap { |s| s.bind('127.0.0.1', 0) } }
    let(:receiver_port) { receiver.addr[1] }

    after { receiver.close }

    def device(**opts)
      LogStashLogger::Device.new({ type: :udp, host: '127.0.0.1', port: receiver_port, sync: true,
                                   error_logger: ::Logger.new(error_log) }.merge(opts))
    end

    def received(count)
      Array.new(count) do
        break unless IO.select([receiver], nil, nil, 2)
        receiver.recvfrom(70_000).first
      end.compact
    end

    it "defaults max_datagram_size to the IPv4 UDP payload limit" do
      expect(device.max_datagram_size).to eq(65_507)
    end

    it "replaces a JSON string with a large non-message field, even with max_message_size set" do
      LogStashLogger.configure { |config| config.max_message_size = 2000 }
      logger = LogStashLogger.new(type: :udp, host: '127.0.0.1', port: receiver_port, sync: true,
                                  max_datagram_size: 4000, error_logger: ::Logger.new(error_log))
      logger.info('before')
      logger.warn(%Q({"message":"short","details":"#{'secret' * 12_000}"}))
      logger.info('after')

      before, stub, after = received(3).map { |datagram| JSON.parse(datagram) }
      expect([before['message'], after['message']]).to eq(%w[before after])
      expect(stub['message']).to match(/\ARecord of \d+ bytes replaced: too large for one UDP datagram\z/)
      expect(stub['original_size']).to be > 72_000
      expect(stub['tags']).to eq(['_logstashlogger_record_too_large'])
      expect(stub).not_to have_key('details')
      expect(error_log.string).to match(/replacing a record of \d+ bytes that does not fit in one datagram \(max_datagram_size: 4000\)/)
      expect(error_log.string).not_to include('secret')
    end

    it "replaces a record that is not JSON" do
      device(max_datagram_size: 1000).write('x' * 2000)
      expect(JSON.parse(received(1).first)).to include('original_size' => 2000)
    end

    it "accepts a String value, as URI query options arrive" do
      dev = LogStashLogger::Device.new(uri: "udp://127.0.0.1:#{receiver_port}?max_datagram_size=1000")
      expect(dev.max_datagram_size).to eq(1000)
    end

    it "rejects a value that is not a number of bytes, or is below 512" do
      expect { device(max_datagram_size: 'lots') }.to raise_error(ArgumentError)
      expect { device(max_datagram_size: nil) }.to raise_error(ArgumentError)
      expect { device(max_datagram_size: 100) }.to raise_error(ArgumentError, /at least 512/)
    end

    it "rejects an invalid value before starting the buffer" do
      expect_any_instance_of(described_class).not_to receive(:buffer_initialize)
      expect { device(max_datagram_size: 100) }.to raise_error(ArgumentError)
    end
  end
end
