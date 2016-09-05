require_relative 'serialization_providers/json_serialization_provider'
require_relative 'serialization_providers/oj_serialization_provider'

module EventQ
  module SerializationProviders

    OJ_PROVIDER = 'oj'.freeze
    JSON_PROVIDER = 'json'.freeze

    class Manager
      def initialize
        @providers = {}
        @providers[OJ_PROVIDER] = EventQ::SerializationProviders::OjSerializationProvider.new
        @providers[JSON_PROVIDER] = EventQ::SerializationProviders::JsonSerializationProvider.new
      end

      def get_provider(provider_type)
        provider = @providers[provider_type]
        if provider == nil
          raise "Invalid provider type specified: #{provider_type}"
        end
        return provider
      end
    end
  end
end