require 'logstash-logger'

describe LogStashLogger::Device::Kafka do
  include_context 'device'

  let(:producer) { double("Poseidon::Producer") }

  before(:each) do
    allow(Poseidon::Producer).to receive(:new) { producer }
  end

  it "writes to a Kafka topic" do
    expect(producer).to receive(:send_messages)
    kafka_device.write "foo"
  end

  it "defaults the Kafka hosts to ['localhost:9092']" do
    expect(kafka_device.hosts).to eq(['localhost:9092'])
  end

  it "defaults the Kafka topic to 'logstash'" do
    expect(kafka_device.topic).to eq('logstash')
  end

  it "defaults the Kafka producer to 'logstash-logger'" do
    expect(kafka_device.producer).to eq('logstash-logger')
  end

  it "defaults the Kafka backoff to 1" do
    expect(kafka_device.backoff).to eq(1)
  end
end
