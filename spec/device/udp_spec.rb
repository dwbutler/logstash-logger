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

    it "replaces a JSON string with a large non-message field, even with max_message_size set" do
      LogStashLogger.configure { |config| config.max_message_size = 2000 }
      logger = LogStashLogger.new(type: :udp, host: '127.0.0.1', port: receiver_port, sync: true,
                                  error_logger: ::Logger.new(error_log))
      logger.info('before')
      logger.warn(%Q({"message":"short","details":"#{'secret' * 12_000}"}))
      logger.info('after')

      before, stub, after = received(3).map { |datagram| JSON.parse(datagram) }
      expect([before['message'], after['message']]).to eq(%w[before after])
      expect(stub['message']).to match(/\ARecord of \d+ bytes replaced: too large for one UDP datagram\z/)
      expect(stub['original_size']).to be > 72_000
      expect(stub['tags']).to eq(['_logstashlogger_record_too_large'])
      expect(stub).not_to have_key('details')
      expect(error_log.string).to match(/replacing a record of \d+ bytes that does not fit in one datagram/)
      expect(error_log.string).not_to include('secret')
    end

    it "replaces a record that is not JSON" do
      device.write('x' * 70_000)
      expect(JSON.parse(received(1).first)).to include('original_size' => 70_000)
    end
  end
end
