require 'logstash-logger'

describe LogStashLogger::Device::Kinesis do
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
    failed_record.error_code = "ServiceUnavailable"
    failed_record.error_message = "ServiceUnavailable"
    response = ::Aws::Firehose::Types::PutRecordBatchOutput.new
    response.failed_put_count = 1
    response.request_responses = [failed_record]

    expect(client).to receive(:put_record_batch) { response }
    expect(firehose_device).to receive(:write).with("foo")

    firehose_device.write_one "foo"
  end

  it "defaults the AWS region to us-east-1" do
    expect(firehose_device.aws_region).to eq('us-east-1')
  end

  it "defaults the Firehose stream to logstash" do
    expect(firehose_device.stream).to eq('logstash')
  end
end
