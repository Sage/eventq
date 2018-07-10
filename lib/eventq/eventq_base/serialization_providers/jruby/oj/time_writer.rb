module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class TimeWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(Time)
          end
          def exec(obj)
            {
              '^t': obj.to_f
            }
          end
        end
      end
    end
  end
end
