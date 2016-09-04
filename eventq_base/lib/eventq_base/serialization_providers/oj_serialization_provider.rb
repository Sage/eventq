module EventQ
  module SerializationProviders
    class OjSerializationProvider
      def serialize(object)
        Oj.dump(object)
      end

      def deserialize(json)
        Oj.load(json)
      end
    end
  end
end