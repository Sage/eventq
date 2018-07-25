require 'spec_helper'

RSpec.describe EventQ::SerializationProviders::Manager do
  describe '#get_provider' do
    context 'OJ' do
      it 'returns expected provider' do
        expect(subject.get_provider(EventQ::SerializationProviders::OJ_PROVIDER))
            .to be_a EventQ::SerializationProviders::OjSerializationProvider
      end
    end
  end
end
