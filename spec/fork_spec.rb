require 'logstash-logger'
require_relative 'support/recording_device'

describe 'Logging from a forked process' do
  before { skip 'fork is not available' unless Process.respond_to?(:fork) && RUBY_ENGINE == 'ruby' }

  # Runs the block in a child process and returns what it writes to the pipe.
  def in_child
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      # An error is reported as a value; raising here would run the parent's
      # RSpec and SimpleCov exit hooks in the child.
      result = begin
        yield
      rescue Exception => e
        "#{e.class}: #{e.message}"
      end
      writer.write(Marshal.dump(result))
      writer.close
      exit!(0)
    end
    writer.close
    result = reader.read
    Process.wait(pid)
    Marshal.load(result)
  end

  it "sends only the child's records from the child, with a running timer" do
    device = RecordingDevice.new(buffer_max_interval: 3600)
    device.write('parent')

    lines, timer_alive = in_child do
      device.write('child')
      device.buffer_flush(force: true)
      [device.lines, device.timer.alive?]
    end

    expect(lines).to eq(['child'])
    expect(timer_alive).to be(true)
    expect(device.lines).to be_empty
  end
end
