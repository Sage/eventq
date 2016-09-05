module EventQ
  class Configuration

    def self.serialization_provider=(value)
      @serialization_provider = value
    end

    def self.serialization_provider
      if @serialization_provider == nil
        @serialization_provider = EventQ::SerializationProviders::OJ_PROVIDER
      end
      return @serialization_provider
    end

  end
end