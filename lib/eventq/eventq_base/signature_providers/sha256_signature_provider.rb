module EventQ
  module SignatureProviders
    class Sha256SignatureProvider

      def initialize
        require 'openssl'
        require 'base64'
        @serializer = serialization_provider_manager.get_provider(EventQ::Configuration.serialization_provider)
      end

      #This method is called to create a signature for a message
      def write(message:, secret:)
        json = @serializer.serialize(message.content)
        hash = OpenSSL::HMAC.digest('sha256', secret, json)
        Base64.encode64(hash)
      end

      #This method is called to validate a message signature
      def valid?(message:, secret:)
        signature = write(message: message, secret: secret)
        message.signature == signature
      end

      private

      def serialization_provider_manager
        EventQ::SerializationProviders::Manager.new
      end
    end
  end
end
