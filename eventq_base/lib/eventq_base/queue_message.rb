module EventQ
  class QueueMessage
    extend ClassKit

    attr_accessor_type :id, type: String
    attr_accessor_type :retry_attempts, type: Integer
    attr_accessor_type :type, type: String
    attr_accessor_type :content
    attr_accessor_type :created, type: Time
    attr_accessor_type :signature, type: String
    attr_accessor_type :context, type: Hash

    def initialize
      @retry_attempts = 0
      @created = Time.now.to_i
      @id = SecureRandom.uuid
      @context = {}
    end

    # Creates a signature for the message
    #
    # @param provider [EventQ::SignatureProviders::Sha256SignatureProvider] Signature provider that implements
    #   a write method
    def sign(provider)
      return unless EventQ::Configuration.signature_secret

      self.signature = provider.write(message: self, secret: EventQ::Configuration.signature_secret)
    end
  end
end
