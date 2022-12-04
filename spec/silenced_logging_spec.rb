# frozen_string_literal: true

require 'logstash-logger'

describe LogStashLogger do
  include_context 'logger'

  describe 'silenced logging' do

    it 'yields the logger' do
      logger.silence do |yielded|
        expect(yielded).to eq(logger)
      end
    end

    it 'silences any message below ERROR level by default' do
      logger.silence do
        expect(logger.device).to receive(:write).once
        logger.info('info')
        logger.warn('warning')
        logger.error('error')
      end
    end

    it 'takes a custom log level to silence to' do
      logger.silence(::Logger::WARN) do
        expect(logger.device).to receive(:write).once
        logger.info('info')
        logger.warn('warning')
      end
    end
  end
end
