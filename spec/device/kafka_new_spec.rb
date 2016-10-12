require 'logstash-logger'

describe LogStashLogger::Device::KafkaNew::TLSConfiguration do
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

describe LogStashLogger::Device::KafkaNew do
  include_context 'device'

  let(:broker_hosts) { "localhost:9300 localhost:9232" }
  let(:opts) do
    { topic: 'hello-world',
      brokers: broker_hosts,
    }
  end
  let(:instance) { LogStashLogger::Device::KafkaNew.new(opts) }

  describe "initializing" do
    context "brokers" do
      context "when array" do
        it "sets the brokers array to @brokers" do
          brokers = %w(localhost:9300 localhost:9232)
          instance = LogStashLogger::Device::KafkaNew.new(opts.merge({brokers: brokers}))

          expect(instance.brokers).to be_kind_of Array
          expect(instance.brokers.length).to eql(2)
        end

        it 'sets the brokers to an array if a string is passed in' do
          brokers = "localhost:9300 localhost:9232"
          instance = LogStashLogger::Device::KafkaNew.new(opts.merge({brokers: brokers}))
          expect(instance.brokers).to be_kind_of Array
          expect(instance.brokers.length).to eql(2)
        end
      end
    end

    context "topic" do
      it 'sets the topic to the option provided' do
        instance = described_class.new(topic: 'hello-world')
        expect(instance.topic).to eql('hello-world')
      end

      it 'raises an exception if no topic is set' do
        expect {
          described_class.new(topic: nil)
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
              opts = complete_bundle.merge(brokers: broker_hosts)
              opts[param] = nil
              expect {
                LogStashLogger::Device::KafkaNew.new(opts).connection
              }.to raise_error( ArgumentError )
            end
          end
        end

        context "complete cert bundle" do

          it 'correctly passes in the cert bundle to the Kafka Client' do
            certopts = complete_bundle.merge(opts)

            expect_any_instance_of(::Kafka::Client).to receive(:build_ssl_context) 
              .with(certopts[:ssl_ca_cert], certopts[:ssl_client_cert], certopts[:ssl_client_cert_key])
              .and_return(true)

            LogStashLogger::Device::KafkaNew.new(certopts).connection
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

      expect(instance).to receive(:connection).and_return(connect_double)
      expect(connect_double).to receive(:producer)
      expect(producer).to receive(:produce).and_return(true)
      expect(producer).to receive(:deliver_messages).and_return(true)
      instance.write_one("hello world")
    end
  end
end
