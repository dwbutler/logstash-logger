require 'logstash-logger'

describe LogStashLogger::Device::Kinesis do
  include_context 'device'

  let(:client) { double("Aws::Kinesis::Client") }

  before(:each) do
    allow(Aws::Kinesis::Client).to receive(:new) { client }
  end

  it "writes to a Kinesis stream" do
    response = ::Aws::Kinesis::Types::PutRecordsOutput.new
    response.failed_record_count = 0
    response.records = []
    expect(client).to receive(:put_records) { response }
    kinesis_device.write "foo"

    expect(kinesis_device).to be_connected
    kinesis_device.close!
    expect(kinesis_device).not_to be_connected
  end

  it "empties the AWS SDK connection pools and builds a new client in a forked process" do
    response = ::Aws::Kinesis::Types::PutRecordsOutput.new
    response.failed_record_count = 0
    response.records = []
    allow(client).to receive(:put_records) { response }
    allow(Aws).to receive(:empty_connection_pools!)
    kinesis_device.write "parent"
    expect(Aws).not_to have_received(:empty_connection_pools!)

    # Block form: the timer thread may call Process.pid while the stub is set up

    child_pid = Process.pid + 1

    allow(Process).to receive(:pid) { child_pid }
    kinesis_device.write "child"

    expect(Aws).to have_received(:empty_connection_pools!).once
    expect(Aws::Kinesis::Client).to have_received(:new).twice
  end

  it "empties the AWS SDK connection pools in a forked process even without a client" do
    allow(Aws).to receive(:empty_connection_pools!)
    kinesis_device.close!

    # Block form: the timer thread may call Process.pid while the stub is set up

    child_pid = Process.pid + 1

    allow(Process).to receive(:pid) { child_pid }
    kinesis_device.connected?

    expect(Aws).to have_received(:empty_connection_pools!).once
  end

  it "leaves the pools alone and warns on an aws-sdk-core release whose empty! is broken" do
    stub_const('Aws::CORE_GEM_VERSION', '3.195.0')
    allow(Aws).to receive(:empty_connection_pools!)
    error_log = StringIO.new
    device = LogStashLogger::Device.new(type: :kinesis, sync: true, error_logger: ::Logger.new(error_log))

    # Block form: the timer thread may call Process.pid while the stub is set up

    child_pid = Process.pid + 1

    allow(Process).to receive(:pid) { child_pid }
    device.connected?

    expect(Aws).not_to have_received(:empty_connection_pools!)
    expect(error_log.string).to include('upgrade to 3.196.1 or later')
  end

  it "empties the pools on aws-sdk v2, which has no CORE_GEM_VERSION" do
    hide_const('Aws::CORE_GEM_VERSION')
    allow(Aws).to receive(:empty_connection_pools!)
    kinesis_device

    # Block form: the timer thread may call Process.pid while the stub is set up

    child_pid = Process.pid + 1

    allow(Process).to receive(:pid) { child_pid }
    kinesis_device.connected?

    expect(Aws).to have_received(:empty_connection_pools!).once
  end

  it "it puts records with recoverable errors back in the buffer" do
    failed_record = ::Aws::Kinesis::Types::PutRecordsResultEntry.new
    failed_record.error_code = "ProvisionedThroughputExceededException"
    failed_record.error_message = "ProvisionedThroughputExceededException"
    response = ::Aws::Kinesis::Types::PutRecordsOutput.new
    response.failed_record_count = 1
    response.records = [failed_record]

    expect(client).to receive(:put_records) { response }
    expect(kinesis_device).not_to receive(:write)

    kinesis_device.write_one "foo"
    state = kinesis_device.instance_variable_get(:@buffer_state)
    expect(state[:pending_items][nil]).to eq(["foo"])
    expect(state[:pending_count]).to eq(1)
  end

  it "defaults the kinesis stream to logstash" do
    expect(kinesis_device.stream).to eq('logstash')
  end
end
