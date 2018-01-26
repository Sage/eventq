module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class AttributeWriter

          def self.exec(obj)
            aw = descendants.detect { |a| a.new.valid?(obj) } || ClassWriter
            aw.new.exec(obj)
          end

          def self.descendants
            descendants = []
            ObjectSpace.each_object(singleton_class) do |k|
              next if k.singleton_class?
              descendants.unshift k unless k == self
            end
            descendants
          end
        end
      end
    end
  end
end
