# frozen_string_literal: true

module LogStashLogger
  module Formatter
    class Cee < Base
      private

      def format_event(event)
        "@cee:#{event.to_json}"
      end
    end
  end
end
