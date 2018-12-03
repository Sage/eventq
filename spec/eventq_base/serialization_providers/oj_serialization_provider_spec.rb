require 'spec_helper'

class TestObject
  attr_accessor :name
  attr_accessor :age
end

RSpec.describe EventQ::SerializationProviders::OjSerializationProvider do
  describe '#serialize' do
    context 'when passing a general object' do
      let(:object) do
        TestObject.new.tap do |e|
          e.name = 'Jane Doe',
          e.age = 34
        end
      end

      specify do
        json = subject.serialize(object)
        obj = Oj.load(json)
        expect(obj.name).to eql object.name
        expect(obj.age).to eql object.age
      end
    end

    context 'when passing a hash' do
      let(:object) { { name: 'Jane Doe', age: 34 } }

      specify do
        expect(subject.serialize(object)).to eql Oj.dump(object)
      end
    end
  end
end
