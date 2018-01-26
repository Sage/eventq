module EventQ
  module SerializationProviders
    module JRuby
      class OjSerializationProvider
        def initialize
          @json_serializer = EventQ::SerializationProviders::JsonSerializationProvider.new
          @oj_serializer = Oj::Serializer.new
        end

        def serialize(object)
          @oj_serializer.dump(object)
        end

        def deserialize(json)
          begin
            return @oj_serializer.load(json)
          rescue
            EventQ.log(:debug, "[#{self.class}] - Failed to deserialize using Oj, falling back to JsonSerializationProvider.")
            return @json_serializer.deserialize(json)
          end
        end
      end
    end
  end
end
