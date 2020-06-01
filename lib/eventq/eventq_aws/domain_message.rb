# frozen_string_literal: true

module EventQ
  module Amazon
    # Domain message
    class DomainMessage
      attr_reader :id, :published_at

      attr_accessor :topic, :content, :correlation

      def initialize
        @id = SecureRandom.uuid
        @published_at = Time.now.to_f
      end
    end
  end
end
