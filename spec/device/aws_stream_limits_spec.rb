require 'logstash-logger'
require 'logger'

# Stub AWS clients that record every request and can be told to fail.
class FakeKinesisClient
  attr_reader :requests

  def initialize(fail_requests: [])
    @requests = []
    @fail_requests = fail_requests
  end

  def put_records(params)
    @requests << params[:records].map { |r| r[:data] }
    raise Seahorse::Client::NetworkingError.new(StandardError.new('connection reset')) if @fail_requests.include?(@requests.size)
    entries = params[:records].map { Aws::Kinesis::Types::PutRecordsResultEntry.new(sequence_number: '1', shard_id: 's') }
    Aws::Kinesis::Types::PutRecordsOutput.new(failed_record_count: 0, records: entries)
  end
end

class FakeFirehoseClient
  attr_reader :requests

  def initialize
    @requests = []
  end

  def put_record_batch(params)
    @requests << params[:records].map { |r| r[:data] }
    entries = params[:records].map { Aws::Firehose::Types::PutRecordBatchResponseEntry.new(record_id: '1') }
    Aws::Firehose::Types::PutRecordBatchOutput.new(failed_put_count: 0, request_responses: entries)
  end
end

describe 'AWS outputs and service limits' do
  let(:error_log) { StringIO.new }
  let(:common) do
    { sync: false, buffer_max_interval: 3600, buffer_flush_at_exit: false,
      aws_region: 'us-east-1', error_logger: ::Logger.new(error_log) }
  end
  let(:small) { (1..5).map { |i| %({"n":#{i}}) } }

  def pending_count(device)
    device.instance_variable_get(:@buffer_state)[:pending_count]
  end

  describe LogStashLogger::Device::Kinesis do
    let(:client) { FakeKinesisClient.new }
    let(:device) { LogStashLogger::Device.new(common.merge(type: :kinesis)) }

    before { allow(Aws::Kinesis::Client).to receive(:new) { client } }

    it 'drops only a record over the per-record limit' do
      device.write_batch(small + ['x' * 1_048_576])
      expect(client.requests).to eq([small])
      expect(error_log.string).to match(/dropping a record of 1048612 bytes: over the 1048576-byte limit/)
    end

    it 'accepts larger records when aws_max_record_bytes is raised' do
      big = 'x' * 2_000_000
      device = LogStashLogger::Device.new(common.merge(type: :kinesis, aws_max_record_bytes: 10_485_760))
      device.write_batch([big])
      expect(client.requests).to eq([[big]])
    end

    it 'splits more than 500 records into several requests' do
      messages = (1..600).map(&:to_s)
      device.write_batch(messages)
      expect(client.requests.map(&:size)).to eq([500, 100])
    end

    it 'splits requests that would go over the request-size limit' do
      messages = Array.new(12) { 'x' * 1_000_000 }
      device.write_batch(messages)
      expect(client.requests.map(&:size)).to eq([10, 2])
    end

    it 'sends records that are not Strings as text' do
      device.write_batch([123, :sym])
      expect(client.requests).to eq([['123', 'sym']])
    end

    context 'when a request fails' do
      let(:client) { FakeKinesisClient.new(fail_requests: [1]) }

      it 'keeps the records for the next flush instead of treating them as delivered' do
        small.each { |m| device.write(m) }
        expect { device.buffer_flush(force: true) }.not_to raise_error
        expect(pending_count(device)).to eq(small.size)
        expect(error_log.string).to include('5 records will be retried on the next flush')
      end

      it 'drops them when drop_messages_on_flush_error is set' do
        device = LogStashLogger::Device.new(common.merge(type: :kinesis, drop_messages_on_flush_error: true))
        small.each { |m| device.write(m) }
        device.buffer_flush(force: true)
        expect(pending_count(device)).to eq(0)
        expect(error_log.string).to include('dropping 5 records after a failed request')
      end
    end

    context 'when a later request fails' do
      let(:client) { FakeKinesisClient.new(fail_requests: [2]) }

      it 'retries only the records that were not sent' do
        device.write_batch((1..600).map(&:to_s))
        expect(pending_count(device)).to eq(100)
      end
    end

    it 'delivers the rest of a buffered batch around an oversized record' do
      small.each { |m| device.write(m) }
      device.write('x' * 2_000_000)
      device.buffer_flush(force: true)
      expect(client.requests).to eq([small])
      expect(pending_count(device)).to eq(0)
    end
  end

  describe LogStashLogger::Device::Firehose do
    let(:client) { FakeFirehoseClient.new }
    let(:device) { LogStashLogger::Device.new(common.merge(type: :firehose)) }

    before { allow(Aws::Firehose::Client).to receive(:new) { client } }

    it 'drops only a record over the 1,000 KiB limit' do
      device.write_batch(small + ['x' * 1_024_001])
      expect(client.requests).to eq([small])
    end

    it 'splits requests at 4 MB' do
      device.write_batch(Array.new(5) { 'x' * 1_000_000 })
      expect(client.requests.map(&:size)).to eq([4, 1])
    end
  end
end

# Throttles every record of the first `throttled` requests, then accepts all.
class ThrottlingKinesisClient
  attr_reader :requests

  def initialize(throttled:, code: 'ProvisionedThroughputExceededException')
    @requests = []
    @throttled = throttled
    @code = code
  end

  def put_records(params)
    @requests << params[:records].map { |r| r[:data] }
    if @requests.size <= @throttled
      entries = params[:records].map { Aws::Kinesis::Types::PutRecordsResultEntry.new(error_code: @code, error_message: 'slow down') }
      Aws::Kinesis::Types::PutRecordsOutput.new(failed_record_count: entries.size, records: entries)
    else
      entries = params[:records].map { Aws::Kinesis::Types::PutRecordsResultEntry.new(sequence_number: '1', shard_id: 's') }
      Aws::Kinesis::Types::PutRecordsOutput.new(failed_record_count: 0, records: entries)
    end
  end

  def delivered
    @requests.drop(@throttled).flatten
  end
end

describe LogStashLogger::Device::Kinesis, 'when records are throttled' do
  let(:error_log) { StringIO.new }
  let(:client) { ThrottlingKinesisClient.new(throttled: 1) }
  let(:records) { (1..50).map(&:to_s) }

  before { allow(Aws::Kinesis::Client).to receive(:new) { client } }

  def device(**opts)
    LogStashLogger::Device.new({ type: :kinesis, aws_region: 'us-east-1', sync: false, buffer_max_interval: 0.2,
                                 buffer_flush_at_exit: false, error_logger: ::Logger.new(error_log) }.merge(opts))
  end

  # These flushes run on the buffer's background timer thread, so poll until
  # the block returns true, giving up after `timeout` seconds. The example's
  # own expectations then report what went wrong if it never does.
  def wait_until(timeout: 5)
    deadline = Time.now + timeout
    sleep 0.05 until yield || Time.now > deadline
  end

  it 'retries a full throttled batch on the timer thread without losing it or stopping the timer' do
    dev = device
    timer = dev.instance_variable_get(:@flush_timer_thread)
    records.each { |r| dev.write(r) }

    # Records are delivered before the flush updates its counts
    wait_until { client.delivered.size == records.size && dev.instance_variable_get(:@buffer_state)[:outgoing_count] == 0 }

    expect(client.delivered).to match_array(records)
    expect(dev.instance_variable_get(:@buffer_state)[:pending_count]).to eq(0)
    expect(dev.instance_variable_get(:@buffer_state)[:outgoing_count]).to eq(0)
    expect(timer).to be_alive
    expect(error_log.string).to include('50 records will be retried on the next flush (ProvisionedThroughputExceededException: 50)')
    expect(error_log.string).not_to include('Buffer Full')
  end

  it 'does not block logging when drop_messages_on_full_buffer is false' do
    dev = device(drop_messages_on_full_buffer: false)
    records.each { |r| dev.write(r) }
    wait_until { client.delivered.size == records.size }

    writer = Thread.new { dev.write('after') }
    expect(writer.join(2)).not_to be_nil
    expect(client.delivered).to match_array(records)
  end

  context 'with InternalFailure' do
    let(:client) { ThrottlingKinesisClient.new(throttled: 1, code: 'InternalFailure') }

    it 'retries the records' do
      dev = device
      records.first(3).each { |r| dev.write(r) }
      wait_until { client.delivered.size == 3 }
      expect(client.delivered).to match_array(records.first(3))
    end
  end
end
