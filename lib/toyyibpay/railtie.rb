# frozen_string_literal: true

require "rails/railtie"

module ToyyibPay
  # Rails integration
  class Railtie < Rails::Railtie
    railtie_name :toyyibpay

    # Load configuration from Rails credentials or environment variables
    initializer "toyyibpay.configure" do |app|
      ToyyibPay.configure do |config|
        # Try Rails credentials first (Rails 5.2+)
        if app.respond_to?(:credentials) && app.credentials.toyyibpay
          config.api_key = app.credentials.toyyibpay[:api_key]
          config.category_code = app.credentials.toyyibpay[:category_code]
          config.sandbox = app.credentials.toyyibpay[:sandbox] || false
        else
          # Fall back to environment variables
          config.api_key = ENV["TOYYIBPAY_API_KEY"]
          config.category_code = ENV["TOYYIBPAY_CATEGORY_CODE"]
          config.sandbox = ENV["TOYYIBPAY_SANDBOX"] == "true"
        end

        # Set Rails logger
        config.logger = Rails.logger if Rails.logger
      end
    end

    # Add generators
    generators do |g|
      g.templates.unshift File.expand_path("../generators/templates", __dir__)
    end
  end
end
