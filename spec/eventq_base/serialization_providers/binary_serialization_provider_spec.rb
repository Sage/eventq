require 'spec_helper'

class TestClass
  attr_accessor :name
  attr_accessor :age
end

RSpec.describe EventQ::SerializationProviders::BinarySerializationProvider do

  let(:object) do
    TestClass.new.tap do |e|
      e.name = 'joe'
      e.age = 33
    end
  end

  describe '#serialize' do
    context 'when passing a general object' do
      specify do
        expect(subject.serialize(object)).to eq Marshal::dump(object)
      end
    end

    context 'when passing a hash' do
      let(:object) { { name: 'Jane Doe', age: 34 } }

      specify do
        expect(subject.serialize(object)).to eq Marshal::dump(object)
      end
    end
  end
  describe '#deserialize' do
    context 'when receiving a general object' do

      let(:serialized) { Marshal::dump(object) }

      specify do
        expect(subject.deserialize(serialized)).to be_a(TestClass)
      end
    end

    context 'when receiving a hash' do
      let(:object) { { name: 'Jane Doe', age: 34 } }
      let(:serialized) { Marshal::dump(object) }

      specify do
        expect(subject.deserialize(serialized)).to eq object
      end
    end
  end
end
