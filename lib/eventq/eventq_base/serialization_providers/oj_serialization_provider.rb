module EventQ
  module SerializationProviders
    class OjSerializationProvider

      def initialize
        require 'oj'
        @json_serializer = EventQ::SerializationProviders::JsonSerializationProvider.new
      end

      def serialize(object)
        Oj.dump(object, mode: :object)
      end

      def deserialize(json)
        begin
          Oj.load(json)
        rescue Oj::ParseError, ArgumentError
          EventQ.log(:debug, "[#{self.class}] - Failed to deserialize using Oj, falling back to JsonSerializationProvider.")
          @json_serializer.deserialize(json)
        end
      end
    end
  end
end
