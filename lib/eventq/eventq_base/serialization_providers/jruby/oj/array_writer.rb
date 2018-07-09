module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class ArrayWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(Array)
          end
          def exec(obj)
            array = []
            obj.each do |a|
              array << AttributeWriter.exec(a)
            end
            array
          end
        end
      end
    end
  end
end
