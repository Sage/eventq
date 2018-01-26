module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class DateTimeWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(DateTime)
          end
          def exec(obj)
            seconds = obj.strftime('%S%N')
            d = 1_000_000_000
            if seconds.start_with?('0')
              seconds[0] = ''
              d = 100_000_000
            end

            {
              '^O': 'DateTime',
              year: obj.year,
              month: obj.month,
              day: obj.day,
              hour: obj.hour,
              min: obj.min,
              sec: RationalWriter.new.exec(Rational(Integer(seconds), d)),
              offset: RationalWriter.new.exec(obj.offset),
              start: obj.start
            }
          end
        end
      end
    end
  end
end
