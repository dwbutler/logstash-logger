require 'spec_helper'

describe LogStashLogger do
  # The type of socket we're testing
  def socket_type
    @socket_type ||= (ENV['SOCKET_TYPE'] || 'UDP').to_s.downcase.to_sym
  end
  
  before(:all) { puts "Testing with #{socket_type.to_s.upcase} socket type" }
  
  let(:host) { '0.0.0.0' }
  let(:hostname) { Socket.gethostname }
  let(:port) { 5228 }
  
  # The logstash logger
  let(:logger) { LogStashLogger.new(host, port, socket_type) }
  # The log device that the logger writes to
  let(:logdev) { logger.instance_variable_get(:@logdev) }
  
  let! :listener do
    case socket_type
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
    case socket_type
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
  
  it 'uses a LogStashLogger::Socket as the log device' do
    logdev.should be_a Logger::LogDevice
    logdev.instance_variable_get(:@dev).should be_a LogStashLogger::Socket
  end

  it 'takes a string message as input and writes a logstash event' do
    message = 'test'

    logdev.should_receive(:write).and_call_original do |event|
      event.should be_a LogStash::Event
      event.source.should eql(hostname)
      event['message'].should eql(message)
      event['severity'].should eql('INFO')
    end

    logger.info(message)
    
    listener_event['message'].should == message
  end
  
  it 'takes a logstash-formatted json string as input and writes out a logstash event' do
    logdev.should_receive(:write).and_call_original do |event|
      event.should be_a LogStash::Event
      event['message'].should eql(logstash_event['message'])
      event.source.should eql(hostname)
    end

    logger.info(logstash_event.to_json)
    
    listener_event['message'].should == logstash_event['message']
  end
  
  it 'takes a LogStash::Event as input and writes it out intact' do
    logdev.should_receive(:write).and_call_original do |event|
      event.should be_a LogStash::Event
      event['message'].should eql(logstash_event['message'])
      event['severity'].should eql(logstash_event['severity'])
      event.timestamp.should eql(logstash_event.timestamp)
      event.source.should eql(hostname)
    end
    
    logger.warn(logstash_event)
    
    listener_event['message'].should == logstash_event['message']
    listener_event['severity'].should == logstash_event['severity']
  end
  
  it 'takes a data hash as input and writes out a logstash event' do
    data = {
      "message" => 'test',
      'severity' => 'INFO'
    }
    
    logdev.should_receive(:write).and_call_original do |event|
      event.should be_a LogStash::Event
      event['message'].should eql('test')
      event['severity'].should eql('INFO')
      event.source.should eql(hostname)
    end

    logger.info(data.dup)
    
    listener_event['message'].should == data["message"]
    listener_event['severity'].should == data['severity']
  end
  
end