module EventQ
  module SerializationProviders
    class JsonSerializationProvider

      def initialize
        @class_kit_helper = ClassKit::Helper.new
        @hash_helper = HashKit::Helper.new
      end

      def serialize(object)
        hash = @hash_helper.to_hash(object)
        return Json.dump(hash)
      end

      def deserialize(json)
        return @class_kit_helper.from_json(json: json, klass: EventQ::QueueMessage)
      end

    end
  end
end