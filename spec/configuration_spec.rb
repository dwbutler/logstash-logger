require 'logstash-logger'

describe LogStashLogger do

  it 'Initializes with LogStashLogger#config' do
    config = LogStashLogger.config
    expect(config).to be_a LogStashLogger::Configuration
  end

  it 'Initializes custom_fields with sane defaults' do
    config = LogStashLogger.config
    expect(config.custom_fields).to be_a Hash
  end

  it 'Responds to a configuration block sanely' do
    config = LogStashLogger.config do |conf|
      conf.custom_fields = {"test1" => -> {"response1"}}
    end

    expect(config.custom_fields["test1"]).to be_a Proc
  end

  it 'Executes procs' do
    config = LogStashLogger.config do |conf|
      conf.custom_fields["test2"] = -> {"response2"}
    end

    expect(config.custom_fields["test2"].call).to eq("response2")
  end

end
