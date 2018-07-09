module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class HashWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(Hash)
          end
          def exec(obj)
            obj.each do |key, value|
              obj[key] = AttributeWriter.exec(value)
            end
          end
        end
      end
    end
  end
end
