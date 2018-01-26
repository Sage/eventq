require_relative 'serialization_providers/json_serialization_provider'
unless RUBY_PLATFORM =~ /java/
  require_relative 'serialization_providers/oj_serialization_provider'
end
require_relative 'serialization_providers/jruby'
require_relative 'serialization_providers/binary_serialization_provider'

module EventQ
  module SerializationProviders

    OJ_PROVIDER = 'oj'.freeze
    JSON_PROVIDER = 'json'.freeze
    BINARY_PROVIDER = 'binary'.freeze

    class Manager
      def initialize
        @providers = {}
        if RUBY_PLATFORM =~ /java/
          @providers[OJ_PROVIDER] = EventQ::SerializationProviders::Jruby::OjSerializationProvider
        else
          @providers[OJ_PROVIDER] = EventQ::SerializationProviders::OjSerializationProvider
        end
        @providers[JSON_PROVIDER] = EventQ::SerializationProviders::JsonSerializationProvider
        @providers[BINARY_PROVIDER] = EventQ::SerializationProviders::BinarySerializationProvider
      end

      def get_provider(provider_type)
        provider = @providers[provider_type]
        if provider == nil
          raise "Invalid provider type specified: #{provider_type}"
        end
        return provider.new
      end
    end
  end
end
