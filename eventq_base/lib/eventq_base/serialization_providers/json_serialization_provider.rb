module EventQ
  module SerializationProviders
    class JsonSerializationProvider
      def serialize(object)
        Json.dump(object)
      end

      def deserialize(json)
        Json.load(json)
      end
    end
  end
end