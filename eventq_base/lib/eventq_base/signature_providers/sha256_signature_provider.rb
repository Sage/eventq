require 'openssl'
require 'base64'

module EventQ
  module SignatureProviders
    class Sha256SignatureProvider

      def initialize
        @serializer = EventQ::SerializationProviders::JsonSerializationProvider.new
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

    end
  end
end