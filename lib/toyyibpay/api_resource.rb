# frozen_string_literal: true

module ToyyibPay
  # Base class for all API resources
  class APIResource
    attr_reader :client, :data

    def initialize(client, data = {})
      @client = client
      @data = data || {}
    end

    # Allow hash-style access to data
    def [](key)
      @data[key.to_s]
    end

    # Allow method-style access to data
    def method_missing(method_name, *args)
      key = method_name.to_s
      if @data.key?(key)
        @data[key]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @data.key?(method_name.to_s) || super
    end

    # Convert to hash
    def to_h
      @data
    end

    alias to_hash to_h

    # Convert to JSON
    def to_json(*args)
      @data.to_json(*args)
    end

    # Inspect
    def inspect
      "#<#{self.class.name} #{@data.inspect}>"
    end

    protected

    # Make a request using the client's requestor
    def request(method, path, params = {})
      client.request(method, path, params)
    end

    # Create a resource instance from response data
    def self.construct_from(client, data)
      new(client, data)
    end
  end
end
