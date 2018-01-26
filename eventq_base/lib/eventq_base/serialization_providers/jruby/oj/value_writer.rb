module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class ValueWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(String) || obj.is_a?(Integer) || obj.is_a?(Float)
          end
          def exec(obj)
            obj
          end
        end
      end
    end
  end
end
