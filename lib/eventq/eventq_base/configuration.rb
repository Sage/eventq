module EventQ
  class Configuration

    def self.serialization_provider=(value)
      @serialization_provider = value
    end

    def self.serialization_provider
      if RUBY_PLATFORM =~ /java/
        @serialization_provider ||= EventQ::SerializationProviders::JSON_PROVIDER
      else
        @serialization_provider ||= EventQ::SerializationProviders::OJ_PROVIDER
      end
    end

    def self.signature_provider=(value)
      @signature_provider = value
    end

    def self.signature_provider
      @signature_provider ||= EventQ::SignatureProviders::SHA256
    end

    def self.signature_secret=(value)
      @signature_secret = value
    end

    def self.signature_secret
      @signature_secret
    end

  end
end