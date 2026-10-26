require 'logstash-logger'
require_relative '../support/unserializable_value'
require 'logger'
require 'net/http'

# A record that cannot be formatted must not change how its neighbours are
# framed on the wire.
describe 'Record framing when a record cannot be formatted' do
  let(:failing) { { 'message' => 'x', 'n' => UnserializableValue.new } }
  let(:bad_timestamp) { %q({"message":"y","@timestamp":"not-a-time"}) }

  before do
    LogStashLogger.configure { |c| c.default_error_logger = ::Logger.new(IO::NULL) }
  end

  after { LogStashLogger.configure { |c| c.default_error_logger = ::Logger.new($stderr) } }

  it 'keeps every line of a json_lines stream parseable' do
    io = StringIO.new
    logger = LogStashLogger.new(type: :io, io: io, sync: true)
    logger.info(failing)
    logger.info(bad_timestamp)
    logger.info('next record')

    lines = io.string.lines
    expect(lines.size).to eq(3)
    parsed = lines.map { |l| JSON.parse(l) }
    expect(parsed[0]['tags']).to eq([LogStashLogger::Formatter::Base::FAILED_TO_FORMAT_TAG])
    expect(parsed[1]['message']).to eq('y')
    expect(parsed[2]['message']).to eq('next record')
  end

  it 'keeps every record of a cee_syslog stream on its own line' do
    io = StringIO.new
    logger = LogStashLogger.new(type: :io, io: io, sync: true, formatter: :cee_syslog)
    logger.info(failing)
    logger.info(%q({"message":"z","host":{"hostname":"web1\n<13>forged"}}))
    logger.info('next record')

    lines = io.string.lines
    expect(lines.size).to eq(3)
    lines.each { |l| expect(l).to start_with("#{Socket.gethostname}:@cee:") }
  end

  it 'keeps an HTTP batch a valid JSON array' do
    formatter = LogStashLogger::Formatter.new(:json_lines)
    messages = [failing, 'next record'].map { |m| formatter.call('INFO', Time.now, nil, m) }
    device = LogStashLogger::Device.new(type: :http, url: 'http://localhost', sync: true)
    body = nil
    allow(Net::HTTP).to receive(:post) { |_url, b, _h| body = b; Net::HTTPOK.new('1.1', '200', 'OK') }

    device.write_batch(messages)

    batch = JSON.parse(body)
    expect(batch.size).to eq(2)
    expect(batch[1]['message']).to eq('next record')
  end
end
