module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class DateWriter < ::AttributeWriter
          def valid?(obj)
            obj.is_a?(Date)
          end
          def exec(obj)
            {
              '^O': 'Date',
              year: obj.year,
              month: obj.month,
              day: obj.day,
              start: obj.start
            }
          end
        end
      end
    end
  end
end
