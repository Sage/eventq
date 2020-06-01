# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EventQ::Amazon::DomainMessage do
  describe '#new' do
    it 'initialises id' do
      expect(subject.id).not_to be_nil
    end

    it 'initialises published_at' do
      expect(subject.published_at).not_to be_nil
    end
  end
end
