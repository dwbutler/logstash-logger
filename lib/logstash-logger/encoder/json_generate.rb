module LogStashLogger
  module Encoder
    class JsonGenerate
      def call(event)
        JSON.generate(event)
      end
    end
  end
end
