require 'logstash-logger'

describe LogStashLogger::Device::Kafka::TLSConfiguration do
  context "with TLS" do
    let(:complete_bundle) do
      # NOTE these keys are obviously fake. We don't actually make connections
      {
        ssl_ca_cert: "----BEGIN CERT---- lkajdslkajdsjk ----END CERT---",
        ssl_client_cert:      "----BEGIN CERT---- lkajdslkajdsjk ----END CERT---",
        ssl_client_cert_key: "----PRIVATE---- lkajdslkajdsjk ----PRIVATE---",
      }
    end

    context "when complete params are passed in" do
      let(:instance) { described_class.new(complete_bundle) }

      it "returns an empty hash when no ssl params are initialized" do
        expect(instance.cert_bundle).to_not be_empty
        expect(instance.valid?).to be_truthy
      end
    end

    context "when incomplete params are passed in" do
      [:ssl_ca_cert, :ssl_client_cert, :ssl_client_cert_key].each do |param|
        it "fails with an ArgumentError when #{param} no provided" do
          opts = complete_bundle
          opts[param] = nil
          instance = described_class.new(opts)
          expect(instance.cert_bundle).to be_empty
          expect(instance.valid?).to be_falsey
        end
      end
    end
  end

  context "without TLS" do
    let(:instance) { subject }

    it "returns an empty hash when no ssl params are initialized" do
      expect(instance.cert_bundle).to be_empty
      expect(instance.valid?).to be_truthy
    end
  end

  context "#invalid?" do
    it 'is just the opposite of valid?' do
      expect(subject).to receive(:valid?).and_return(false)
      expect(subject.invalid?).to be_truthy

      expect(subject).to receive(:valid?).and_return(true)
      expect(subject.invalid?).to be_falsey
    end
  end
end

describe LogStashLogger::Device::Kafka do
  include_context 'device'

  let(:broker_hosts) { "localhost:9300 localhost:9232" }
  let(:opts) do
    { topic: 'hello-world',
      brokers: broker_hosts,
    }
  end
  let(:instance) { LogStashLogger::Device::Kafka.new(opts) }
  let(:brokers) { %w(localhost:9300 localhost:9232) }

  describe "initializing" do
    context "brokers" do
      context "when array" do
        it "sets the brokers array to @brokers" do
          instance = LogStashLogger::Device::Kafka.new(opts.merge({brokers: brokers}))

          expect(instance.brokers).to eql(brokers)
        end

        it 'sets the brokers to an array if a string is passed in' do
          instance = LogStashLogger::Device::Kafka.new(opts.merge({brokers: broker_hosts}))
          expect(instance.brokers).to eql(brokers)
        end
      end

      context "when missing or empty" do
        it "raises an error if brokers are nil" do
          expect {
            described_class.new(topic: 'hello-world', brokers: nil)
          }.to raise_error(ArgumentError)
        end

        it "raises an error if brokers are an empty array" do
          expect {
            described_class.new(topic: 'hello-world', brokers: [])
          }.to raise_error(ArgumentError)
        end

        it "raises an error if brokers are blank" do
          expect {
            described_class.new(topic: 'hello-world', brokers: "  ")
          }.to raise_error(ArgumentError)
        end
      end
    end

    context "topic" do
      it 'sets the topic to the option provided' do
        instance = described_class.new(topic: 'hello-world', brokers: brokers)
        expect(instance.topic).to eql('hello-world')
      end

      it 'raises an exception if no topic is set' do
        expect {
          described_class.new(topic: nil)
        }.to raise_error(ArgumentError)
      end

      it 'raises an exception if the topic is blank' do
        expect {
          described_class.new(topic: "  ", brokers: brokers)
        }.to raise_error(ArgumentError)
      end
    end

    context "Client Introspection" do
      # YUCK! ruby-kafka does not presently allow reading certain variables
      module ::Kafka
        class Client
          attr_reader :connection_builder
        end
      end

      module ::Kafka
        class ConnectionBuilder
          attr_reader :ssl_context, :client_id
        end
      end

      context "client_id" do
        it 'sets a client_id when connecting if one is passed in to the options' do
          instance = described_class.new(opts.merge(client_id: 'hello-world'))
          expect(instance.client_id).to eql('hello-world')
          expect(instance.connection.connection_builder.client_id).to eql('hello-world')
        end
      end

      context "cert bundle" do
        let(:complete_bundle) do
          # NOTE these keys are obviously fake. We don't actually make connections
          {
            ssl_ca_cert: "----BEGIN CERT---- lkajdslkajdsjk ----END CERT---",
            ssl_client_cert:      "----BEGIN CERT---- lkajdslkajdsjk ----END CERT---",
            ssl_client_cert_key: "----PRIVATE---- lkajdslkajdsjk ----PRIVATE---",
          }
        end

        context "no certs" do
          it 'creates a connection without an ssl_context' do
            connection = instance.connection
            expect(connection.connection_builder.ssl_context).to be_nil
          end
        end

        context "partial certs passed in" do
          it 'fails if the complete cert suite is not passed in' do
            [:ssl_ca_cert, :ssl_client_cert, :ssl_client_cert_key].each do |param|
              base_opts = opts
              invalid_opts = complete_bundle.merge(base_opts)
              invalid_opts[param] = nil
              expect {
                LogStashLogger::Device::Kafka.new(invalid_opts).connection
              }.to raise_error( ArgumentError )
            end
          end
        end

        context "complete cert bundle" do

          it 'correctly passes in the cert bundle to the Kafka Client' do
            certopts = complete_bundle.merge(opts)

            ssl_context = double("ssl_context")
            expect(::Kafka::SslContext).to receive(:build)
              .with(hash_including(
                ca_cert: certopts[:ssl_ca_cert],
                client_cert: certopts[:ssl_client_cert],
                client_cert_key: certopts[:ssl_client_cert_key],
              ))
              .and_return(ssl_context)

            LogStashLogger::Device::Kafka.new(certopts).connection
          end
        end
      end
    end
  end

  describe "writing single message to broker" do
    it 'writes the message to the topic' do
      producer = double('producer', produce: true)
      connect_double = double("connection", producer: producer)
      instance = described_class.new(opts)

      # NOTE: this is stubbing out the ruby-kafka API
      expect(instance).to receive(:connection).and_return(connect_double)
      expect(connect_double).to receive(:producer)
      expect(producer).to receive(:produce).and_return(true)
      expect(producer).to receive(:deliver_messages).and_return(true)
      instance.write_one("hello world")
    end

    it 'is capabable of writing to a different topic than instantiated' do
      producer = double('producer', produce: lambda {|message, topic| "hi" })
      connect_double = double("connection", producer: producer)
      instance = described_class.new(opts)

      message = 'hello world'
      topic   = 'my topic'
      # NOTE: this is stubbing out the ruby-kafka API
      expect(instance).to receive(:connection).and_return(connect_double)
      expect(connect_double).to receive(:producer)
      expect(producer).to receive(:produce).
                            with(message, topic: topic).
                            and_return(true)
      expect(producer).to receive(:deliver_messages).and_return(true)

      instance.write_one(message, topic)
    end
  end

  describe "error handling" do
    it "clears the producer and connection when an error occurs" do
      producer = double('producer')
      allow(producer).to receive(:produce).and_raise(StandardError, "boom")
      allow(producer).to receive(:deliver_messages)

      connection = double("connection", producer: producer, close: true)
      instance = described_class.new(opts)

      allow(instance).to receive(:connection).and_return(connection)
      expect(connection).to receive(:close)

      expect {
        instance.write_one("hello world")
      }.to raise_error(StandardError)

      expect(instance.instance_variable_get(:@producer)).to be_nil
      expect(instance.instance_variable_get(:@io)).to be_nil
    end
  end

  describe "buffer group" do
    it "uses the topic so final flush does not pass a boolean topic" do
      instance = described_class.new(opts)

      expect(instance).to receive(:write_batch).with(['hello world'], 'hello-world')
      instance.write('hello world')
      instance.buffer_flush(final: true)
    end
  end

  describe "writing a batch of messages to the broker" do
    it "writes the messages to the topic" do
      producer = double('producer', produce: lambda {|message, topic| "hi" })
      connect_double = double("connection", producer: producer)
      instance = described_class.new(opts)

      messages = ['hello world', 'goodbye world']
      topic   = 'my topic'
      # NOTE: this is stubbing out the ruby-kafka API
      expect(instance).to receive(:connection).and_return(connect_double)
      expect(connect_double).to receive(:producer)
      expect(producer).to receive(:produce).
                            with(messages.first, topic: topic).
                            and_return(true)
      expect(producer).to receive(:produce).
                            with(messages.last, topic: topic).
                            and_return(true)
      expect(producer).to receive(:deliver_messages).and_return(true)

      instance.write_batch(messages, topic)
    end
  end

  describe "connecting/reconnecting" do
    it "sets @io when connecting" do
      instance = described_class.new(opts)
      connection = double("connection")

      instance.instance_variable_set(:@io, connection)
      expect(instance.connect).to eq(connection)
      expect(instance.io).to eq(connection)
    end

    it "reconnects without raising" do
      instance = described_class.new(opts)
      connection = double("connection", close: true)

      allow(instance).to receive(:connection).and_return(connection)
      expect { instance.reconnect }.not_to raise_error
    end
  end

  describe "producer lifecycle" do
    it "memoizes the producer across writes" do
      producer = double('producer', produce: true, deliver_messages: true)
      connection = double("connection", producer: producer)
      instance = described_class.new(opts)

      expect(instance).to receive(:connection).and_return(connection)
      expect(connection).to receive(:producer).once.and_return(producer)

      instance.write_one("hello world")
      instance.write_one("goodbye world")
    end

    it "shuts down the producer on close" do
      instance = described_class.new(opts)
      producer = double("producer", shutdown: true)
      connection = double("connection", close: true)

      instance.instance_variable_set(:@producer, producer)
      instance.instance_variable_set(:@io, connection)

      expect(producer).to receive(:shutdown)
      expect(connection).to receive(:close)

      instance.close
    end
  end

  describe "closing connection" do
    it "closes the Kafka connection when present" do
      instance = described_class.new(opts)
      connection = double("connection")
      expect(connection).to receive(:close)

      instance.instance_variable_set(:@io, connection)
      instance.close

      expect(instance.instance_variable_get(:@connection)).to be_nil
    end
  end
end
