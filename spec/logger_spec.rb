require 'spec_helper'

describe LogStashLogger do
  subject { LogStashLogger.new('localhost', port)}
  let(:port) { 5228 }
  let(:server) { TCPServer.new(port) }
  let(:host) { Socket.gethostname }
  
  before(:all) do
    server # Initialize TCP server
  end
  
  let(:logstash_event) do
    event = LogStash::Event.new
    event.message = 'test'
    event['severity'] = 'INFO'
    event
  end
  
  def logdev
    subject.instance_variable_get(:@logdev)
  end
  
  it 'should use TCPClient as the log device' do
    logdev.should be_a Logger::LogDevice
    logdev.instance_variable_get(:@dev).should be_a LogStashLogger::TCPClient
  end

  it 'should take a string message and write a logstash event' do
    message = 'test'
  
    logdev.should_receive(:write) do |event|
      event.should be_a LogStash::Event
      event.source.should eql(host)
      event.message.should eql(message)
      event['severity'].should eql('INFO')
    end

    subject.info(message)
  end
  
  it 'should take a logstash-formatted json string and write out a logstash event' do
    logdev.should_receive(:write) do |event|
      event.should be_a LogStash::Event
      event.message.should eql(logstash_event.message)
      event.source.should eql(host)
    end

    subject.info(logstash_event.to_json)
  end
  
  it 'should take a LogStash::Event and write it out' do
    logdev.should_receive(:write) do |event|
      event.should be_a LogStash::Event
      event.message.should eql(logstash_event.message)
      event['severity'].should eql(logstash_event['severity'])
      event.timestamp.should eql(logstash_event.timestamp)
      event.source.should eql(host)
    end
    
    subject.warn(logstash_event)
  end
  
  it 'should take a hash and write out a logstash event' do
    data = {
      "@message" => 'test',
      'severity' => 'INFO'
    }
    
    logdev.should_receive(:write) do |event|
      event.should be_a LogStash::Event
      event.message.should eql('test')
      event['severity'].should eql('INFO')
      event.source.should eql(host)
    end

    subject.info(data)
  end
  
end