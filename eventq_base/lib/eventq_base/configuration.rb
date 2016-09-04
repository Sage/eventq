module EventQ
  class Configuration

    attr_accessor :serialization_provider

    def initialize
      serialization_provider = EventQ::SerializationProviders::OJ
    end

  end
end