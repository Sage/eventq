require_relative 'test_item'
require 'oj'

RSpec.describe EventQ::SerializationProviders::JRuby::JOj do
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
      e.hash = hash
      e.array_hash = [hash1, hash2]
      e.test_item = item1
      e.array_test_item = [item1, item2]
    end
  end
  describe '#dump' do
    let(:oj_json) { Oj.dump(item3) }
    it 'creates json the same as CRuby OJ' do
      binding.pry
    end
  end
end
