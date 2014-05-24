require 'spec_helper'
require 'active_support/tagged_logging'

describe LogStashLogger do
  include_context 'logger'

  describe "tagged logging" do
    let(:tagged_logger) { ActiveSupport::TaggedLogging.new(logger) }
    let(:message) { 'foo' }
    let(:tag) { 'bar' }

    it "puts tags into the tags array on the logstash event" do
      expect(logdev).to receive(:write) do |event|
        expect(event['tags']).to match_array([tag])
        expect(event['message']).to eq("[#{tag}] #{message}")
      end

      tagged_logger.tagged(tag) do
        tagged_logger.info(message)
      end
    end

    it "doesn't put tags on the even when there are no tags" do
      expect(logdev).to receive(:write) do |event|
        expect(event['tags']).to be_nil
        expect(event['message']).to eq(message)
      end

      tagged_logger.info(message)
    end
  end
end