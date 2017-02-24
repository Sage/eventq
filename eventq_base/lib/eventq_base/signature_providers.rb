require_relative 'signature_providers/sha256_signature_provider'

module EventQ
  module SignatureProviders

    SHA256 = 'sha256'.freeze

    class Manager
      def initialize
        @providers = {}
        @providers[SHA256] = EventQ::SignatureProviders::Sha256SignatureProvider
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