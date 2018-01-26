module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class ClassWriter < AttributeWriter
          def valid?(obj)
            false
          end
          def exec(obj)
            hash = { '^o': obj.class }
            obj.instance_variables.each do |key|
              hash[key[1..-1]] = AttributeWriter.exec(obj.instance_variable_get(key))
            end
            hash
          end
        end
      end
    end
  end
end
