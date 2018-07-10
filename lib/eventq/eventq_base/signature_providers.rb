require_relative 'signature_providers/sha256_signature_provider'

module EventQ
  module SignatureProviders

    SHA256 = 'sha256'.freeze

    class Manager
      def initialize
        @providers = {}
        @providers[SHA256] = EventQ::SignatureProviders::Sha256SignatureProvider
      end

      #This method is called to get a signature provider
      def get_provider(provider_type)
        provider = @providers[provider_type]
        if provider == nil
          raise "Invalid provider type specified: #{provider_type}"
        end
        return provider.new
      end

      #This method is called to validate a queue message's signature
      def validate_signature(message:, queue:)
        valid = true

        if queue.require_signature == true && message.signature == nil
          valid = false
        elsif message.signature != nil
          provider = get_provider(EventQ::Configuration.signature_provider)
          valid = provider.valid?(message: message, secret: EventQ::Configuration.signature_secret)
        end

        if !valid
          raise EventQ::Exceptions::InvalidSignatureException.new
        end

        true

      end

    end
  end
end