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
      expect(stub['severity']).to eq('WARN')
      expect(stub['@timestamp']).to be_a(String)
      expect(stub).not_to have_key('details')
      expect(error_log.string).to match(/replacing a record of \d+ bytes that does not fit in one datagram \(max_datagram_size: 4000\)/)
      expect(error_log.string).not_to include('secret')
    end

    it "keeps a copied field only when it is small" do
      device(max_datagram_size: 1000).write(%Q({"@timestamp":"t","severity":"#{'S' * 1000}","host":"h"}\n))
      stub = received(1).first
      expect(stub).to end_with("\n")
      expect(JSON.parse(stub)).to include('@timestamp' => 't', 'host' => 'h', 'original_size' => 1044)
      expect(JSON.parse(stub)).not_to have_key('severity')
    end

    it "leaves out the copied fields when they would not fit under a small limit" do
      fields = %w[@timestamp host type].map { |key| %Q("#{key}":"#{'v' * 200}") }.join(',')
      device(max_datagram_size: 512).write("{#{fields},\"message\":\"#{'m' * 600}\"}")
      stub = received(1).first
      expect(stub.bytesize).to be <= 512
      expect(JSON.parse(stub).keys).to eq(%w[message tags original_size])
    end

    it "does not parse a record over 1 MiB for fields to copy" do
      device(max_datagram_size: 1000).write(%Q({"severity":"WARN","big":"#{'x' * 1_048_576}"}\n))
      stub = JSON.parse(received(1).first)
      expect(stub).to include('original_size' => 1_048_605)
      expect(stub).not_to have_key('severity')
    end

    { cee: '@cee:', cee_syslog: "#{LogStashLogger::Formatter::HOST['hostname']}:@cee:" }.each do |formatter, header|
      it "keeps the #{formatter} header in the replacement" do
        logger = LogStashLogger.new(type: :udp, host: '127.0.0.1', port: receiver_port, sync: true,
                                    formatter: formatter, max_datagram_size: 1000, error_logger: ::Logger.new(error_log))
        logger.warn('x' * 2000)
        datagram = received(1).first
        expect(datagram).to start_with("#{header}{")
        expect(JSON.parse(datagram.delete_prefix(header))).to include('severity' => 'WARN', 'tags' => ['_logstashlogger_record_too_large'])
      end
    end

    it "keeps a cee_syslog header whose progname has quotes and braces" do
      logger = LogStashLogger.new(type: :udp, host: '127.0.0.1', port: receiver_port, sync: true,
                                  formatter: :cee_syslog, max_datagram_size: 1000, error_logger: ::Logger.new(error_log))
      logger.progname = 'my "app" {1}'
      logger.warn('x' * 2000)
      header = "#{LogStashLogger::Formatter::HOST['hostname']} my \"app\" {1}:@cee:"
      datagram = received(1).first
      expect(datagram).to start_with("#{header}{")
      expect(JSON.parse(datagram.delete_prefix(header))).to include('severity' => 'WARN', 'tags' => ['_logstashlogger_record_too_large'])
    end

    it "skips a copied field that cannot be serialized again" do
      device(max_datagram_size: 1000).write(%Q({"host":1e400,"severity":"WARN","big":"#{'x' * 2000}"}\n))
      stub = JSON.parse(received(1).first)
      expect(stub).to include('severity' => 'WARN')
      expect(stub).not_to have_key('host')
    end

    it "does not treat \"@cee:\" inside a JSON record as a header" do
      device(max_datagram_size: 1000).write(%Q({"message":"@cee:{x}","severity":"WARN","big":"#{'x' * 2000}"}\n))
      expect(JSON.parse(received(1).first)).to include('severity' => 'WARN', 'original_size' => 2050)
    end

    it "leaves out a cee header that would put the replacement over max_datagram_size" do
      logger = LogStashLogger.new(type: :udp, host: '127.0.0.1', port: receiver_port, sync: true,
                                  formatter: :cee_syslog, max_datagram_size: 512, error_logger: ::Logger.new(error_log))
      logger.progname = 'p' * 600
      logger.warn('x' * 2000)
      datagram = received(1).first
      expect(datagram.bytesize).to be <= 512
      expect(JSON.parse(datagram)).to include('tags' => ['_logstashlogger_record_too_large'])
      expect(error_log.string).to match(/leaving out the \d+-byte cee header/)
    end

    it "replaces a record that is not JSON" do
      device(max_datagram_size: 1000).write('x' * 2000)
      expect(JSON.parse(received(1).first)).to include('original_size' => 2000)
    end

    it "replaces a record that the host rejects as too large, under max_datagram_size" do
      dev = device(max_datagram_size: 4000)
      record = %Q({"severity":"ERROR","details":"#{'secret' * 500}"}\n)
      allow(dev.to_io).to receive(:write).and_call_original
      allow(dev.to_io).to receive(:write).with(record).and_raise(Errno::EMSGSIZE)
      dev.write('before')
      dev.write(record)
      dev.write('after')

      before, stub, after = received(3)
      expect([before, after]).to eq(%w[before after])
      expect(JSON.parse(stub)).to include('severity' => 'ERROR', 'original_size' => record.bytesize)
      expect(error_log.string).to include('Errno::EMSGSIZE')
      expect(error_log.string).not_to include('secret')
    end

    context "when the host also rejects the replacement" do
      let(:dev) { device }
      let(:record) { %Q({"severity":"ERROR","details":"#{'secret' * 500}"}\n) }

      def reject_datagrams_containing(*parts)
        allow(dev.to_io).to receive(:write).and_wrap_original do |write, data|
          raise Errno::EMSGSIZE if parts.any? { |part| data.include?(part) }
          write.call(data)
        end
      end

      it "sends the notice alone" do
        reject_datagrams_containing('secret', '"severity"')
        dev.write(record)
        expect(JSON.parse(received(1).first).keys).to eq(%w[message tags original_size])
        expect(error_log.string.scan('Errno::EMSGSIZE').size).to eq(2)
      end

      it "drops the record when the notice is rejected too" do
        reject_datagrams_containing('secret', 'replaced')
        dev.write(record)
        dev.write('after')
        expect(received(1)).to eq(['after'])
        expect(error_log.string.scan('Errno::EMSGSIZE').size).to eq(3)
        expect(error_log.string).to include('unrecoverable error, aborting write')
      end
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
