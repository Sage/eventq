module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class ClassWriter < ::AttributeWriter
          def valid?(obj)
            false
          end
          def exec(obj)
            # TODO:
          end
        end
      end
    end
  end
end
