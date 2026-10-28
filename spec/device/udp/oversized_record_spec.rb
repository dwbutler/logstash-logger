require 'logstash-logger'

describe LogStashLogger::Device::UDP::OversizedRecord do
  let(:warnings) { [] }

  def placeholder(record, max_datagram_size: 1000)
    described_class.new(record, max_datagram_size, warn: ->(message) { warnings << message }).placeholder
  end

  it "keeps a copied field only when it is small" do
    result = placeholder(%Q({"@timestamp":"t","severity":"#{'S' * 1000}","host":"h"}\n))
    expect(result).to end_with("\n")
    expect(JSON.parse(result)).to include('@timestamp' => 't', 'host' => 'h', 'original_size' => 1044)
    expect(JSON.parse(result)).not_to have_key('severity')
  end

  it "leaves out the copied fields when they would not fit under a small limit" do
    fields = %w[@timestamp host type].map { |key| %Q("#{key}":"#{'v' * 200}") }.join(',')
    result = placeholder("{#{fields},\"message\":\"#{'m' * 600}\"}", max_datagram_size: 512)
    expect(result.bytesize).to be <= 512
    expect(JSON.parse(result).keys).to eq(%w[message tags original_size])
  end

  it "does not parse a record over 1 MiB for fields to copy" do
    result = JSON.parse(placeholder(%Q({"severity":"WARN","big":"#{'x' * 1_048_576}"}\n)))
    expect(result).to include('original_size' => 1_048_605)
    expect(result).not_to have_key('severity')
  end

  it "skips a copied field that cannot be serialized again" do
    result = JSON.parse(placeholder(%Q({"host":1e400,"severity":"WARN","big":"#{'x' * 2000}"}\n)))
    expect(result).to include('severity' => 'WARN')
    expect(result).not_to have_key('host')
  end

  it "does not treat \"@cee:\" inside a JSON record as a header" do
    result = placeholder(%Q({"message":"@cee:{x}","severity":"WARN","big":"#{'x' * 2000}"}\n))
    expect(JSON.parse(result)).to include('severity' => 'WARN', 'original_size' => 2050)
  end

  it "builds a placeholder for a record that is not JSON" do
    expect(JSON.parse(placeholder('x' * 2000))).to include('original_size' => 2000)
    expect(warnings).to be_empty
  end

  it "builds a notice-only placeholder that keeps the cee header" do
    record = "host app:@cee:{\"severity\":\"WARN\",\"big\":\"#{'x' * 2000}\"}\n"
    result = described_class.new(record, 1000).notice_placeholder
    expect(result).to start_with('host app:@cee:{').and end_with("}\n")
    expect(JSON.parse(result.delete_prefix('host app:@cee:')).keys).to eq(%w[message tags original_size])
  end
end
