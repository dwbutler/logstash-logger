require 'logstash-logger'

describe LogStashLogger do
  include_context 'logger'

  let! :listener do
    case connection_type
    when :tcp
      TCPServer.new(port)
    when :udp
      UDPSocket.new.tap {|socket| socket.bind(host, port)}
    end
  end

  # The TCP socket written to by the TCP logstash listener server
  let(:tcp_client) { listener.accept }

  # The logstash event to log
  let(:logstash_event) do
    LogStash::Event.new.tap do |event|
      event['message'] = 'test'
      event['severity'] = 'INFO'
    end
  end

  # The raw input received by the logstash listener
  let :listener_input do
    case connection_type
    when :tcp then tcp_client.readline
    when :udp then listener.recvfrom(8192)[0]
    end
  end

  # The logstash event received by the listener
  let(:listener_event) { LogStash::Event.new(JSON.parse listener_input) }

  #before(:each) do
    # Sync socket writes so we can receive them in the listener immediately
    #@socket = logdev.instance_variable_get(:@dev).send(:connect)
    #@socket.sync = true
  #end

  after(:each) do
    listener.close
  end

  # The socket that the logger is writing to
  #let(:socket) { @socket }

  it 'uses a LogStashLogger::Device as the log device' do
    expect(logdev).to be_a Logger::LogDevice
    expect(logdev.instance_variable_get(:@dev)).to be_a LogStashLogger::Device::Base
  end

  it 'takes a string message as input and writes a logstash event' do
    message = 'test'
    logger.info(message)

    expect(listener_event['severity']).to eql('INFO')
    expect(listener_event['message']).to eq(message)
    expect(listener_event['host']).to eq(hostname)
  end

  it 'takes a logstash-formatted json string as input and writes out a logstash event' do
    logger.info(logstash_event.to_json)

    expect(listener_event['message']).to eq(logstash_event['message'])
    expect(listener_event['host']).to eq(hostname)
  end

  it 'takes a LogStash::Event as input and writes it out intact' do
    logger.warn(logstash_event)

    expect(listener_event['message']).to eq(logstash_event['message'])
    expect(listener_event['severity']).to eq(logstash_event['severity'])
    expect(listener_event['@timestamp'].iso8601).to eq(logstash_event.timestamp.iso8601)
    expect(listener_event['host']).to eq(hostname)
  end

  it 'takes a data hash as input and writes out a logstash event' do
    data = {
      'message' => 'test',
      'severity' => 'INFO',
      'foo' => 'bar'
    }

    logger.info(data.dup)

    expect(listener_event['message']).to eq(data["message"])
    expect(listener_event['severity']).to eq(data['severity'])
    expect(listener_event['foo']).to eq(data['foo'])
    expect(listener_event['host']).to eq(hostname)
    expect(listener_event['@timestamp']).to_not be_nil
  end

  it 'takes any object as input and writes a logstash event' do
    message = Time.now

    logger.info(message)

    expect(listener_event['message']).to eq(message.inspect)
    expect(listener_event['host']).to eq(hostname)
    expect(listener_event['severity']).to eq('INFO')
  end

  it 'allows event to be customized via configuration' do
    LogStashLogger.configure do |config|
      config.customize_event do |event|
        event["test1"] = "response1"
      end
    end

    logger.info("test")

    expect(listener_event["test1"]).to eq("response1")
  end

end
