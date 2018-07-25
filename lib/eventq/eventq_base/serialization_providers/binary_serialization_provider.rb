module EventQ
  module SerializationProviders
    class BinarySerializationProvider

      def serialize(object)
        Marshal::dump(object)
      end

      def deserialize(msg)
        Marshal::load(msg)
      end

    end
  end
end
