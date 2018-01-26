module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class Serializer
          def dump(obj)
            JSON.dump(AttributeWriter.exec(obj))
          end

          def load(json)
            raise NotImplementedError.new("[#{self.class}] - #load method has not yet been implemented.")
          end
        end
      end
    end
  end
end
