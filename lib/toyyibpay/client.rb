# frozen_string_literal: true

module ToyyibPay
  # Main client for interacting with the toyyibPay API
  class Client
    attr_reader :config, :requestor

    # Initialize a new ToyyibPay client
    #
    # @param api_key [String] Your toyyibPay API secret key
    # @param options [Hash] Optional configuration
    # @option options [String] :category_code Default category code for bills
    # @option options [Boolean] :sandbox Use sandbox mode (default: false)
    #
    # @example
    #   client = ToyyibPay::Client.new("your-secret-key")
    #   client = ToyyibPay::Client.new("your-secret-key", sandbox: true)
    #   client = ToyyibPay::Client.new("your-secret-key", category_code: "abc123")
    def initialize(api_key = nil, options = {})
      @config = build_config(api_key, options)
      @requestor = APIRequestor.new(@config)
    end

    # Create a new client with global configuration
    #
    # @return [ToyyibPay::Client]
    def self.default_client
      new(ToyyibPay.api_key, ToyyibPay.configuration.instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete("@").to_sym
        hash[key] = ToyyibPay.configuration.instance_variable_get(var)
      end)
    end

    # Enable sandbox mode
    def use_sandbox!
      @config.sandbox = true
      self
    end

    # Disable sandbox mode
    def use_production!
      @config.sandbox = false
      self
    end

    # Check if using sandbox mode
    def sandbox?
      @config.sandbox
    end

    # Make a request to the API
    def request(method, path, params = {})
      @requestor.request(method, path, params)
    end

    # Bank operations
    def banks
      @banks ||= Resources::Bank.new(self)
    end

    # Package operations
    def packages
      @packages ||= Resources::Package.new(self)
    end

    # Category operations
    def categories
      @categories ||= Resources::Category.new(self)
    end

    # Bill operations
    def bills
      @bills ||= Resources::Bill.new(self)
    end

    # Settlement operations
    def settlements
      @settlements ||= Resources::Settlement.new(self)
    end

    # User operations
    def users
      @users ||= Resources::User.new(self)
    end

    private

    def build_config(api_key, options)
      config = Configuration.new

      # Use provided API key or fall back to global config
      config.api_key = api_key || ToyyibPay.api_key

      # Apply options
      options.each do |key, value|
        config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
      end

      config
    end
  end
end
