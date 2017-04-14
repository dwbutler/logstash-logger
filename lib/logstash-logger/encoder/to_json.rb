module LogStashLogger
  module Encoder
    class ToJson
      def call(event)
        event.to_json
      end
    end
  end
end
