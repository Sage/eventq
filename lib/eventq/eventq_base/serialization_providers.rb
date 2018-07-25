require_relative 'serialization_providers/json_serialization_provider'
require_relative 'serialization_providers/oj_serialization_provider'
require_relative 'serialization_providers/binary_serialization_provider'

module EventQ
  module SerializationProviders

    OJ_PROVIDER = 'oj'.freeze
    JSON_PROVIDER = 'json'.freeze
    BINARY_PROVIDER = 'binary'.freeze

    class Manager
      def initialize
        @providers = {}
        @providers[OJ_PROVIDER] = EventQ::SerializationProviders::OjSerializationProvider
        @providers[JSON_PROVIDER] = EventQ::SerializationProviders::JsonSerializationProvider
        @providers[BINARY_PROVIDER] = EventQ::SerializationProviders::BinarySerializationProvider
      end

      def get_provider(provider_type)
        provider = @providers[provider_type]
        if provider.nil?
          raise "Invalid provider type specified: #{provider_type}"
        end
        return provider.new
      end
    end
  end
end
