module EventQ
  module SerializationProviders
    class JsonSerializationProvider

      def initialize
        @class_kit_helper = ClassKit::Helper.new
        @hash_helper = HashKit::Helper.new
      end

      def serialize(object)
        JSON.dump(object_to_hash(object))
      end

      def deserialize(json)
        return @class_kit_helper.from_json(json: json, klass: EventQ::QueueMessage)
      end

      private

      def object_to_hash(object)
        return object if object.is_a?(Hash)
        @hash_helper.to_hash(object)
      end
    end
  end
end
