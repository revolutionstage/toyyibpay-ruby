# frozen_string_literal: true

# ToyyibPay Configuration
# For more information, see https://github.com/revolutionstage/toyyibpay-rails

ToyyibPay.configure do |config|
  # Your toyyibPay API secret key
  # Get this from https://toyyibpay.com (production) or https://dev.toyyibpay.com (sandbox)
  config.api_key = ENV["TOYYIBPAY_API_KEY"]

  # Optional: Default category code for bills
  config.category_code = ENV["TOYYIBPAY_CATEGORY_CODE"]

  # Use sandbox mode for testing (default: false)
  # Set to true to use https://dev.toyyibpay.com
  config.sandbox = ENV.fetch("TOYYIBPAY_SANDBOX", "false") == "true"

  # Optional: Configure timeouts (in seconds)
  # config.open_timeout = 30
  # config.read_timeout = 80
  # config.write_timeout = 30

  # Optional: Configure retry behavior
  # config.max_retries = 2

  # Optional: Set custom logger
  # config.logger = Rails.logger
end
