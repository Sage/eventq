require 'spec_helper'

RSpec.describe EventQ::SerializationProviders::JsonSerializationProvider do
  describe '#serialize' do
    context 'when passing a general object' do
      let(:object_class) do
        Class.new do
          def initialize
            @name = 'John Doe'
            @age = 33
          end
        end
      end
      let(:object) { object_class.new }
      let(:expected) { { name: 'John Doe', age: 33 }.to_json }

      specify do
        expect(subject.serialize(object)).to eql expected
      end
    end

    context 'when passing a hash' do
      let(:object) { { name: 'Jane Doe', age: 34 } }
      let(:expected) { object.to_json }

      specify do
        expect(subject.serialize(object)).to eql expected
      end
    end
  end
end
