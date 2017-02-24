module EventQ
  class Configuration

    def self.serialization_provider=(value)
      @serialization_provider = value
    end

    def self.serialization_provider
      if @serialization_provider == nil
        @serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
      @serialization_provider
    end

    def self.signature_provider=(value)
      @signature_provider = value
    end

    def self.signature_provider
      if @signature_provider == nil
        @signature_provider = EventQ::SignatureProviders::SHA256
      end
      @signature_provider
    end

    def self.signature_secret=(value)
      @signature_secret = value
    end

    def self.signature_secret
      @signature_secret
    end

  end
end