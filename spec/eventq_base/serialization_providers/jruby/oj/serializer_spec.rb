require_relative 'test_item'

RSpec.describe EventQ::SerializationProviders::JRuby::Oj::Serializer do
  let(:hash1) do
    { string: 'foo', time: Time.now }
  end
  let(:hash2) do
    { string: 'bar', datetime: DateTime.now }
  end
  let(:item1) do
    TestItem.new.tap do |e|
      e.string = 'foo'
      e.number = 10
      e.float = 12.5
      e.date = Date.today
      e.datetime = DateTime.now
      e.time = Time.now
    end
  end
  let(:item2) do
    TestItem.new.tap do |e|
      e.string = 'bar'
      e.number = 34
      e.float = 50.02
      e.date = Date.today
      e.datetime = DateTime.now
      e.time = Time.now
    end
  end
  let(:item3) do
    TestItem.new.tap do |e|
      e.string = 'bar'
      e.number = 20
      e.float = 22.2
      e.date = Date.today
      e.datetime = DateTime.now
      e.time = Time.now
      e.hash = hash1.dup
      e.array_hash = [hash1.dup, hash2.dup]
      e.test_item = item1.dup
      e.array_test_item = [item1.dup, item2.dup]
    end
  end

  describe '#dump' do
    let(:json) { subject.dump(item3) }
    unless RUBY_PLATFORM =~ /java/
      require 'oj'

      it 'creates json that CRuby OJ can deserialize' do
        p '*****************************************'
        p "item3.date #{item3.date}"
        p "item3.datetime #{item3.datetime}"
        p "item3.time #{item3.time}"
        p "json = #{json}"
        p '*****************************************'
        itm = Oj.load(json)
        expect(itm).to be_a(TestItem)
        expect(itm.string).to eq item3.string
        expect(itm.number).to eq item3.number
        expect(itm.float).to eq item3.float
        expect(itm.date).to eq item3.date
        expect(itm.datetime).to eq item3.datetime

        # Had to round to millionth otherwise off by a ten of a millionth of a decimal. 1×10−7
        expect(itm.time.to_f.round(6)).to eq item3.time.to_f.round(6)
        expect(itm.hash).to be_a(Hash)
        expect(itm.hash['string']).to eq hash1[:string]
        # Had to round to millionth otherwise off by a ten of a millionth of a decimal. 1×10−7
        expect(itm.hash['time'].to_f.round(6)).to eq hash1[:time].to_f.round(6)
        expect(itm.array_hash).to be_a(Array)
        expect(itm.array_hash.length).to eq 2
        expect(itm.test_item).to be_a(TestItem)
        expect(itm.test_item.string).to eq item1.string
        expect(itm.array_test_item).to be_a(Array)
        expect(itm.array_test_item.length).to eq 2
      end
    end

    it 'serializes to json in a timely manner' do
      require 'benchmark'
      Benchmark.measure { subject.dump(item3) }
    end
  end
end
