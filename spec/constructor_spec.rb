require 'logstash-logger'

describe LogStashLogger do
  describe '.new' do
    it 'returns a Logger instance' do
      expect(LogStashLogger.new(type: :stdout)).to be_a ::Logger
    end

    context 'type: :multi_logger' do
      it "returns an instance of LogStashLogger::MultiLogger" do
        expect(LogStashLogger.new(type: :multi_logger)).to be_a LogStashLogger::MultiLogger
      end

      it 'merges top level configuration into each logger' do
        logger = LogStashLogger.new(type: :multi_logger, port: 1234, outputs: [ { type: :tcp  }, { type: :udp } ])
        logger.loggers.each do |logger|
          expect(logger.device.port).to eq(1234)
        end
      end

      context 'with a top level formatter and customize_event' do
        let(:ios) { [StringIO.new, StringIO.new] }
        let(:customize_event) { ->(event) { event['password'] = '[FILTERED]' } }

        it 'applies them to each logger' do
          logger = LogStashLogger.new(
            type: :multi_logger,
            formatter: :json,
            customize_event: customize_event,
            outputs: ios.map { |io| { type: :io, io: io } }
          )
          logger.info('message' => 'login', 'password' => 'secret')

          logger.loggers.each do |child|
            expect(child.formatter).to be_a LogStashLogger::Formatter::Json
          end
          ios.each do |io|
            expect(JSON.parse(io.string)['password']).to eq('[FILTERED]')
          end
        end

        it 'lets an output override them' do
          logger = LogStashLogger.new(
            type: :multi_logger,
            formatter: :json,
            customize_event: customize_event,
            outputs: [
              { type: :io, io: ios[0], formatter: :json_lines },
              { type: :io, io: ios[1], customize_event: ->(event) { event['password'] = 'hidden' } }
            ]
          )
          logger.info('message' => 'login', 'password' => 'secret')

          expect(logger.loggers[0].formatter).to be_a LogStashLogger::Formatter::JsonLines
          expect(JSON.parse(ios[0].string)['password']).to eq('[FILTERED]')
          expect(logger.loggers[1].formatter).to be_a LogStashLogger::Formatter::Json
          expect(JSON.parse(ios[1].string)['password']).to eq('hidden')
        end
      end
    end

    context 'logger_class: CustomLogger' do
      class CustomLogger < Logger; end

      it 'should create a logger of the specified class' do
        expect(LogStashLogger.new(type: :stdout, :logger_class => CustomLogger)).to be_a CustomLogger
      end
    end
  end
end
