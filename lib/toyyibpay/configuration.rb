# frozen_string_literal: true

module ToyyibPay
  # Configuration class for managing toyyibPay API settings
  class Configuration
    attr_accessor :api_key, :category_code, :sandbox, :api_base, :sandbox_api_base,
                  :open_timeout, :read_timeout, :write_timeout, :max_retries, :logger

    # Default configuration values
    DEFAULT_API_BASE = "https://toyyibpay.com"
    DEFAULT_SANDBOX_API_BASE = "https://dev.toyyibpay.com"
    DEFAULT_OPEN_TIMEOUT = 30
    DEFAULT_READ_TIMEOUT = 80
    DEFAULT_WRITE_TIMEOUT = 30
    DEFAULT_MAX_RETRIES = 2

    def initialize
      @api_key = nil
      @category_code = nil
      @sandbox = false
      @api_base = DEFAULT_API_BASE
      @sandbox_api_base = DEFAULT_SANDBOX_API_BASE
      @open_timeout = DEFAULT_OPEN_TIMEOUT
      @read_timeout = DEFAULT_READ_TIMEOUT
      @write_timeout = DEFAULT_WRITE_TIMEOUT
      @max_retries = DEFAULT_MAX_RETRIES
      @logger = nil
    end

    # Returns the effective API base URL based on sandbox mode
    def effective_api_base
      sandbox ? sandbox_api_base : api_base
    end

    # Validate configuration
    def validate!
      raise ConfigurationError, "API key is required" if api_key.nil? || api_key.empty?
    end

    # Reset to default values
    def reset!
      initialize
    end
  end
end
