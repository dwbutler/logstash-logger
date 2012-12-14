require 'spec_helper'

describe LogStashLogger do
  subject { LogStashLogger.new('0.0.0.0', port)}
  let(:port) { 5228 }
  let(:server) { TCPServer.new(port) }
  
  before(:all) do
    server # Initialize TCP server
  end
  
  let(:logstash_event) do
    event = LogStash::Event.new
    event.message = 'test'
    event['severity'] = 'INFO'
    event
  end
  
  context 'add' do
    it 'should take a string message and write a logstash event' do
      message = 'test'
    
      subject.client.should_receive(:write) do |event|
        event.should be_a LogStash::Event
        event.message.should eql(message)
        event['severity'].should eql('INFO')
      end
  
      subject.info(message)
    end
    
    it 'should take a logstash-formatted json string and write out a logstash event' do
      subject.client.should_receive(:write) do |event|
        event.should be_a LogStash::Event
        event.message.should eql(logstash_event.message)
      end

      subject.info(logstash_event.to_json)
    end
    
    it 'should take a LogStash::Event and write it out' do
      subject.client.should_receive(:write).with(logstash_event)
      
      subject.warn(logstash_event)
    end
    
    it 'should take a hash and write out a logstash event' do
      data = {
        "@message" => 'test',
        'severity' => 'INFO'
      }
      
      subject.client.should_receive(:write) do |event|
        event.should be_a LogStash::Event
        event.message.should eql('test')
        event['severity'].should eql('INFO')
      end
  
      subject.info(data)
    end
    
  end
  
end