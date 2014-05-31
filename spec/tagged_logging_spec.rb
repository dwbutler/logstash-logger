require 'logstash-logger'

describe LogStashLogger do
  include_context 'logger'

  describe "tagged logging" do
    let(:message) { 'foo' }
    let(:tag) { 'bar' }

    it "puts tags into the tags array on the logstash event" do
      expect(logdev).to receive(:write) do |event_string|
        event = JSON.parse(event_string)
        expect(event['tags']).to match_array([tag])
        expect(event['message']).to eq(message)
      end

      logger.tagged(tag) do
        logger.info(message)
      end
    end

    it "doesn't put tags on the event when there are no tags" do
      expect(logdev).to receive(:write) do |event_string|
        event = JSON.parse(event_string)
        expect(event['tags']).to be_nil
        expect(event['message']).to eq(message)
      end

      logger.info(message)
    end
  end
end