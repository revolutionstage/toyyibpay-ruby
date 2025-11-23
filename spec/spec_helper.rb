# frozen_string_literal: true

require "toyyibpay"
require "webmock/rspec"

# Disable external HTTP requests
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration before each test
  config.before(:each) do
    ToyyibPay.reset_configuration!
  end
end

# Helper methods for tests
module ToyyibPayTestHelpers
  def configure_toyyibpay
    ToyyibPay.configure do |config|
      config.api_key = "test-secret-key"
      config.category_code = "test-category"
      config.sandbox = true
    end
  end

  def stub_toyyibpay_request(method, path, response_body:, status: 200)
    url = "#{ToyyibPay.configuration.effective_api_base}#{path}"
    stub_request(method, url)
      .to_return(
        status: status,
        body: response_body.is_a?(String) ? response_body : response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

RSpec.configure do |config|
  config.include ToyyibPayTestHelpers
end
