require 'logstash-logger'

describe LogStashLogger::Device::File do
  include_context 'device'

  it "writes to a file" do
    expect(file_device.to_io).to be_a ::File
  end

  context "with shift options" do
    let(:shift_file) do
      temp = Tempfile.new('logstash_shift')
      temp.close
      temp
    end

    let(:shift_device) do
      LogStashLogger::Device.new(
        type: :file,
        path: shift_file.path,
        shift_age: 1,
        shift_size: 1
      )
    end

    let(:period_file) do
      temp = Tempfile.new('logstash_period_shift')
      temp.close
      temp
    end

    let(:period_device) do
      LogStashLogger::Device.new(
        type: :file,
        path: period_file.path,
        shift_age: 'daily',
        shift_period_suffix: '%Y-%m-%d'
      )
    end

    after do
      shift_device.close
      ::Dir.glob("#{shift_file.path}*").each do |path|
        ::File.delete(path) if ::File.exist?(path)
      end

      period_device.close
      ::Dir.glob("#{period_file.path}*").each do |path|
        ::File.delete(path) if ::File.exist?(path)
      end
    end

    it "wraps a Logger::LogDevice for rotation" do
      expect(shift_device.io).to be_a ::Logger::LogDevice
      expect(shift_device.to_io).to be_a ::File
    end

    it "rotates when shift_size is exceeded" do
      shift_device.write("a" * 10)
      shift_device.write("b" * 10)
      shift_device.close

      expect(::File.exist?("#{shift_file.path}.0")).to be(true)
    end

    it "uses shift_period_suffix for time-based rotation" do
      period_device.write("a")
      period_device.io.send(:shift_log_period, Time.new(2026, 1, 22))
      period_device.close

      expect(::File.exist?("#{period_file.path}.2026-01-22")).to be(true)
    end
  end

  context "when path is not specified" do
    it "raises an exception" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end
end
