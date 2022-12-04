# frozen_string_literal: true

require 'logstash-logger'

describe LogStashLogger::Device::Kinesis do
  include_context 'device'

  let(:client) { double('Aws::Kinesis::Client') }

  before(:each) do
    allow(Aws::Kinesis::Client).to receive(:new) { client }
  end

  it 'writes to a Kinesis stream' do
    response = ::Aws::Kinesis::Types::PutRecordsOutput.new
    response.failed_record_count = 0
    response.records = []
    expect(client).to receive(:put_records) { response }
    kinesis_device.write 'foo'

    expect(kinesis_device).to be_connected
    kinesis_device.close!
    expect(kinesis_device).not_to be_connected
  end

  it 'it puts records with recoverable errors back in the buffer' do
    failed_record = ::Aws::Kinesis::Types::PutRecordsResultEntry.new
    failed_record.error_code = 'ProvisionedThroughputExceededException'
    failed_record.error_message = 'ProvisionedThroughputExceededException'
    response = ::Aws::Kinesis::Types::PutRecordsOutput.new
    response.failed_record_count = 1
    response.records = [failed_record]

    expect(client).to receive(:put_records) { response }
    expect(kinesis_device).to receive(:write).with('foo')

    kinesis_device.write_one 'foo'
  end

  it 'defaults the kinesis stream to logstash' do
    expect(kinesis_device.stream).to eq('logstash')
  end
end
