module EventQ
  module SerializationProviders
    class OjSerializationProvider

      def initialize
        @json_serializer = EventQ::SerializationProviders::JsonSerializationProvider.new
      end

      def serialize(object)
        return Oj.dump(object)
      end

      def deserialize(json)
        begin
          return Oj.load(json)
        rescue Oj::ParseError
          return @json_serializer.deserialize(json)
        end
      end
    end
  end
end