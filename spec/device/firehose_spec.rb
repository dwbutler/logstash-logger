require 'logstash-logger'

describe LogStashLogger::Device::Firehose do
  include_context 'device'

  let(:client) { double("Aws::Firehose::Client") }

  before(:each) do
    allow(Aws::Firehose::Client).to receive(:new) { client }
  end

  it "writes to a Firehose stream" do
    response = ::Aws::Firehose::Types::PutRecordBatchOutput.new
    response.failed_put_count = 0
    response.request_responses = []
    expect(client).to receive(:put_record_batch) { response }
    firehose_device.write "foo"

    expect(firehose_device).to be_connected
    firehose_device.close!
    expect(firehose_device).not_to be_connected
  end

  it "it puts records with recoverable errors back in the buffer" do
    failed_record = ::Aws::Firehose::Types::PutRecordBatchResponseEntry.new
    failed_record.error_code = "InternalFailure"
    failed_record.error_message = "InternalFailure"
    response = ::Aws::Firehose::Types::PutRecordBatchOutput.new
    response.failed_put_count = 1
    response.request_responses = [failed_record]

    expect(client).to receive(:put_record_batch) { response }
    expect(firehose_device).not_to receive(:write)

    firehose_device.write_one "foo"
    state = firehose_device.instance_variable_get(:@buffer_state)
    expect(state[:pending_items][nil]).to eq(["foo"])
    expect(state[:pending_count]).to eq(1)
  end

  it "defaults the Firehose stream to logstash" do
    expect(firehose_device.stream).to eq('logstash')
  end
end
