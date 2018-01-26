module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class DateTimeWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(DateTime)
          end
          def exec(obj)
            {
              '^O': 'DateTime',
              year: obj.year,
              month: obj.month,
              day: obj.day,
              hour: obj.hour,
              min: obj.min,
              sec: RationalWriter.new.exec(Rational(Integer(obj.strftime('%S%N')), 1000000000)),
              offset: RationalWriter.new.exec(obj.offset),
              start: obj.start
            }
          end
        end
      end
    end
  end
end
