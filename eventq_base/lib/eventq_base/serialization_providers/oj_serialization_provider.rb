module EventQ
  module SerializationProviders
    class OjSerializationProvider

      def initialize
        @json_serializer = EventQ::SerializationProviders::JsonSerializationProvider.new
      end

      def serialize(object)
        require 'oj'
        return Oj.dump(object, mode: :object)
      end

      def deserialize(json)
        require 'oj'
        begin
          return Oj.load(json)
        rescue Oj::ParseError
          EventQ.log(:debug, "[#{self.class}] - Failed to deserialize using Oj, falling back to JsonSerializationProvider.")
          return @json_serializer.deserialize(json)
        end
      end
    end
  end
end