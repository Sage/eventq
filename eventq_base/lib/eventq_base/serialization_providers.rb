require_relative 'serialization_providers/json_serialization_provider'
require_relative 'serialization_providers/oj_serialization_provider'

module EventQ
  module SerializationProviders

    OJ = 'oj'.freeze
    JSON = 'json'.freeze

    class Manager
      def initialize
        @providers = {}
        @providers[OJ] = EventQ::SerializationProviders::OjSerializationProvider.new
        @providers[JSON] = EventQ::SerializationProviders::JsonSerializationProvider.new
      end

      def get_provider(provider_type)
        provider = @providers[provider_type]
        if provider == nil
          raise "Invalid provider type spedcified: #{provider_type}"
        end
        return provider
      end
    end
  end
end