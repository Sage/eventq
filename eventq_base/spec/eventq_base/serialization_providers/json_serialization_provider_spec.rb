require 'spec_helper'

RSpec.describe EventQ::SerializationProviders::JsonSerializationProvider do
  describe '#serialize' do
    context 'when passing a general object' do
      let(:object_class) do
        Class.new do
          attr_reader :name, :age
          def initialize
            @name = 'John Doe'
            @age = 33
          end
        end
      end
      let(:object) { object_class.new }

      specify do
        json = subject.serialize(object)
        obj = JSON.load(json)
        expect(obj['name']).to eql object.name
        expect(obj['age']).to eql object.age
      end
    end

    context 'when passing a hash' do
      let(:object) { { name: 'Jane Doe', age: 34 } }

      specify do
        expect(subject.serialize(object)).to eql JSON.dump(object)
      end
    end
  end
end
