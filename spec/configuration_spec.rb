require 'logstash-logger'

describe LogStashLogger do

  it 'Initializes with LogStashLogger#config' do
    config = LogStashLogger.configure
    expect(config).to be_a LogStashLogger::Configuration
  end

  it 'Responds to a configuration block sanely' do
    config = LogStashLogger.configure do |conf|
      conf.customize_event do |event|
        event["test1"] = "response1"
      end
    end

    event = LogStash::Event.new({})
    config.customize_event_block.call(event)
    expect(event["test1"]).to eq("response1")
  end

end
