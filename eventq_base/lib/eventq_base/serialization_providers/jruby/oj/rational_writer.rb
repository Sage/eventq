module EventQ
  module SerializationProviders
    module JRuby
      module Oj
        class RationalWriter < AttributeWriter
          def valid?(obj)
            obj.is_a?(Rational)
          end
          def exec(obj)
            {
              '^O': 'Rational',
              numerator: obj.numerator,
              denominator: obj.denominator
            }
          end
        end
      end
    end
  end
end
