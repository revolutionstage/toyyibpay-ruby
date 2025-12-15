# frozen_string_literal: true

# Standard library dependencies
require "cgi"
require "json"
require "uri"
require "logger"

# Core components
require_relative "toyyibpay/version"
require_relative "toyyibpay/configuration"
require_relative "toyyibpay/errors"
require_relative "toyyibpay/util"
require_relative "toyyibpay/api_requestor"
require_relative "toyyibpay/api_resource"
require_relative "toyyibpay/client"
require_relative "toyyibpay/callback_verifier"

# Compliance utilities
require_relative "toyyibpay/compliance"
require_relative "toyyibpay/audit_logger"
require_relative "toyyibpay/data_retention"

# Resources
require_relative "toyyibpay/resources/bank"
require_relative "toyyibpay/resources/package"
require_relative "toyyibpay/resources/category"
require_relative "toyyibpay/resources/bill"
require_relative "toyyibpay/resources/settlement"
require_relative "toyyibpay/resources/user"

# Ticket and Wallet features
require_relative "toyyibpay/ticket"
require_relative "toyyibpay/wallet"

# Rails integration
require_relative "toyyibpay/railtie" if defined?(Rails::Railtie)

# Main ToyyibPay module
module ToyyibPay
  class << self
    # Global configuration instance
    #
    # @return [ToyyibPay::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure ToyyibPay globally
    #
    # @yield [configuration] Configuration object
    #
    # @example
    #   ToyyibPay.configure do |config|
    #     config.api_key = "your-secret-key"
    #     config.category_code = "your-category-code"
    #     config.sandbox = true
    #   end
    def configure
      yield(configuration) if block_given?
    end

    # Reset global configuration
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Delegate configuration accessors
    def api_key
      configuration.api_key
    end

    def api_key=(value)
      configuration.api_key = value
    end

    def category_code
      configuration.category_code
    end

    def category_code=(value)
      configuration.category_code = value
    end

    def sandbox
      configuration.sandbox
    end

    def sandbox=(value)
      configuration.sandbox = value
    end

    def logger
      configuration.logger
    end

    def logger=(value)
      configuration.logger = value
    end

    # Create a new client with global configuration
    #
    # @return [ToyyibPay::Client]
    def client
      Client.default_client
    end

    # Get default client for internal use
    #
    # @return [ToyyibPay::Client]
    def default_client
      Client.default_client
    end

    # Convenience methods for direct access
    def banks
      client.banks
    end

    def packages
      client.packages
    end

    def categories
      client.categories
    end

    def bills
      client.bills
    end

    def settlements
      client.settlements
    end

    def users
      client.users
    end
  end
end
