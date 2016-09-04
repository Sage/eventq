require_relative 'serialization_providers/json_serialization_provider'
require_relative 'serialization_providers/oj_serialization_provider'

module EventQ
  module SerializationProviders
    OJ = 'oj'.freeze
    JSON = 'json'.freeze
  end
end