# ToyyibPay Ruby Gem

[![Gem Version](https://badge.fury.io/rb/toyyibpay-ruby.svg)](https://badge.fury.io/rb/toyyibpay-ruby)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

Ruby bindings for the [toyyibPay](https://toyyibpay.com) payment gateway API. This gem provides a clean, intuitive interface for integrating toyyibPay into your Ruby and Ruby on Rails applications.

ToyyibPay is a Malaysian payment gateway that supports FPX (online banking) and credit card payments.

## Features

- ✅ Full toyyibPay API v1 support
- ✅ Intuitive, stripe-ruby inspired API design
- ✅ Rails integration with generators and automatic configuration
- ✅ Sandbox mode for testing
- ✅ Comprehensive error handling
- ✅ Thread-safe client implementation
- ✅ Automatic retry with exponential backoff
- ✅ Detailed logging support
- ✅ Well-documented and tested

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'toyyibpay-ruby'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install toyyibpay-ruby
```

## Quick Start

### Ruby

```ruby
require 'toyyibpay'

# Configure globally
ToyyibPay.configure do |config|
  config.api_key = "your-secret-key"
  config.category_code = "your-category-code"
  config.sandbox = true # Use sandbox for testing
end

# Create a bill
bill = ToyyibPay.bills.create(
  billName: "Invoice #001",
  billDescription: "Payment for services",
  billPriceSetting: "0", # 0 = Fixed price, 1 = Open price
  billPayorInfo: "1",    # 0 = Required, 1 = Optional
  billAmount: "10000",   # Amount in cents (RM 100.00)
  billReturnUrl: "https://yoursite.com/payment/return",
  billCallbackUrl: "https://yoursite.com/payment/callback",
  billPaymentChannel: "0" # 0 = FPX, 1 = Credit Card, 2 = Both
)

# Get payment URL
payment_url = ToyyibPay.bills.payment_url(bill[0]["BillCode"])
# => "https://dev.toyyibpay.com/abc123xyz"

# Check bill transactions
transactions = ToyyibPay.bills.transactions(bill[0]["BillCode"])
```

### Rails

1. **Install the gem:**

```bash
bundle add toyyibpay-ruby
```

2. **Run the generator:**

```bash
rails generate toyyibpay:install
```

This creates `config/initializers/toyyibpay.rb` with the configuration template.

3. **Add your credentials:**

**Option A: Environment Variables** (add to `.env` or your environment)

```bash
TOYYIBPAY_API_KEY=your-secret-key
TOYYIBPAY_CATEGORY_CODE=your-category-code
TOYYIBPAY_SANDBOX=true
```

**Option B: Rails Credentials** (Rails 5.2+)

```bash
rails credentials:edit
```

Add:

```yaml
toyyibpay:
  api_key: your-secret-key
  category_code: your-category-code
  sandbox: true
```

4. **Use in your app:**

```ruby
class PaymentsController < ApplicationController
  def create
    bill = ToyyibPay.bills.create(
      billName: "Order ##{@order.id}",
      billDescription: @order.description,
      billPriceSetting: "0",
      billPayorInfo: "1",
      billAmount: (@order.total * 100).to_i.to_s,
      billReturnUrl: payment_return_url,
      billCallbackUrl: payment_callback_url,
      billPaymentChannel: "2"
    )

    redirect_to ToyyibPay.bills.payment_url(bill[0]["BillCode"])
  end

  def callback
    # Handle payment callback
    # toyyibPay will POST to this URL when payment is completed
    bill_code = params[:billcode]
    status = params[:status_id] # 1 = successful, 3 = failed

    if status == "1"
      # Payment successful
      @order.mark_as_paid!
    end

    head :ok
  end
end
```

## Usage

### Configuration

#### Global Configuration

```ruby
ToyyibPay.configure do |config|
  config.api_key = "your-secret-key"           # Required
  config.category_code = "your-category-code"  # Optional default
  config.sandbox = false                       # Default: false

  # Optional: Timeout settings (in seconds)
  config.open_timeout = 30                     # Default: 30
  config.read_timeout = 80                     # Default: 80
  config.write_timeout = 30                    # Default: 30

  # Optional: Retry settings
  config.max_retries = 2                       # Default: 2

  # Optional: Logger
  config.logger = Logger.new(STDOUT)
end
```

#### Per-Client Configuration

```ruby
client = ToyyibPay::Client.new(
  "your-secret-key",
  category_code: "your-category-code",
  sandbox: true
)

# Use the client
bill = client.bills.create(...)
```

### Categories

Categories group related bills together.

```ruby
# Create a category
category = ToyyibPay.categories.create(
  catname: "Product Sales",
  catdescription: "All product sales invoices"
)
# => [{"CategoryCode"=>"abc123xyz"}]

# Get category details
details = ToyyibPay.categories.retrieve("abc123xyz")
```

### Bills

Bills are invoices/payment requests for your customers.

```ruby
# Create a bill with fixed amount
bill = ToyyibPay.bills.create(
  billName: "Invoice #12345",
  billDescription: "Payment for premium subscription",
  billPriceSetting: "0",  # Fixed price
  billPayorInfo: "1",     # Payor info optional
  billAmount: "29900",    # RM 299.00
  billReturnUrl: "https://example.com/return",
  billCallbackUrl: "https://example.com/callback",
  billPaymentChannel: "2", # Both FPX and Credit Card
  billExternalReferenceNo: "ORDER-12345",
  billTo: "customer@example.com",
  billEmail: "noreply@example.com",
  billPhone: "0123456789"
)

# Create a bill with open amount (customer enters amount)
bill = ToyyibPay.bills.create(
  billName: "Donation",
  billDescription: "Support our cause",
  billPriceSetting: "1",  # Open price
  billPayorInfo: "0",     # Payor info required
  billPaymentChannel: "0" # FPX only
)

# Get bill transactions
transactions = ToyyibPay.bills.transactions("bill-code-here")

# Generate payment URL
payment_url = ToyyibPay.bills.payment_url("bill-code-here")

# Run a bill (for recurring bills)
result = ToyyibPay.bills.run(
  billCode: "bill-code-here",
  billpayorEmail: "customer@example.com",
  billpayorName: "John Doe",
  billpayorPhone: "0123456789"
)
```

#### Bill Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `billName` | String | Yes | Name/title of the bill |
| `billDescription` | String | Yes | Description of the bill |
| `billPriceSetting` | String | Yes | `"0"` = Fixed price, `"1"` = Open price |
| `billPayorInfo` | String | Yes | `"0"` = Required, `"1"` = Optional |
| `billAmount` | String | Conditional | Amount in cents (required if `billPriceSetting` = `"0"`) |
| `billReturnUrl` | String | No | URL to redirect after payment |
| `billCallbackUrl` | String | No | URL for payment notifications (POST) |
| `billExternalReferenceNo` | String | No | Your internal reference number |
| `billTo` | String | No | Customer email |
| `billEmail` | String | No | Your email for notifications |
| `billPhone` | String | No | Phone number |
| `billPaymentChannel` | String | No | `"0"` = FPX, `"1"` = Credit Card, `"2"` = Both |
| `billChargeToCustomer` | String | No | `"0"` = No, `"1"` = Yes (pass fees to customer) |
| `billExpiryDate` | String | No | Expiry date (YYYY-MM-DD) |
| `billExpiryDays` | String | No | Days until expiry |

### Banks

```ruby
# Get all available banks
banks = ToyyibPay.banks.all

# Get FPX banks only
fpx_banks = ToyyibPay.banks.fpx
```

### Packages

```ruby
# Get available packages
packages = ToyyibPay.packages.all
```

### Settlements

```ruby
# Get settlement summary for a date
summary = ToyyibPay.settlements.summary(
  settlementDate: "2025-01-15"
)
```

### Users

```ruby
# Get user status
status = ToyyibPay.users.status
```

## Sandbox Mode

ToyyibPay provides a sandbox environment for testing:

1. **Create a sandbox account:** https://dev.toyyibpay.com
2. **Enable sandbox mode:**

```ruby
ToyyibPay.configure do |config|
  config.api_key = "your-sandbox-secret-key"
  config.sandbox = true
end
```

3. **Test payments using bank simulators** available in the sandbox

## Error Handling

The gem provides detailed error classes:

```ruby
begin
  bill = ToyyibPay.bills.create(...)
rescue ToyyibPay::AuthenticationError => e
  # Invalid API key
  puts "Authentication failed: #{e.message}"
rescue ToyyibPay::InvalidRequestError => e
  # Invalid parameters
  puts "Invalid request: #{e.message}"
rescue ToyyibPay::RateLimitError => e
  # Too many requests
  puts "Rate limited: #{e.message}"
rescue ToyyibPay::APIConnectionError => e
  # Network issue
  puts "Connection failed: #{e.message}"
rescue ToyyibPay::TimeoutError => e
  # Request timeout
  puts "Request timed out: #{e.message}"
rescue ToyyibPay::APIError => e
  # Other API error
  puts "API error: #{e.message}"
  puts "Status: #{e.http_status}"
  puts "Body: #{e.http_body}"
rescue ToyyibPay::Error => e
  # Any toyyibPay error
  puts "ToyyibPay error: #{e.message}"
end
```

## Payment Callback

When a payment is completed, toyyibPay will POST to your `billCallbackUrl` with these parameters:

| Parameter | Description |
|-----------|-------------|
| `refno` | Reference number |
| `status` | Payment status |
| `status_id` | Status ID: `1` = successful, `2` = pending, `3` = failed |
| `billcode` | Bill code |
| `order_id` | Order ID |
| `amount` | Amount paid |
| `transaction_time` | Transaction timestamp |

Example Rails controller:

```ruby
class PaymentCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    bill_code = params[:billcode]
    status_id = params[:status_id]
    amount = params[:amount]

    case status_id
    when "1"
      # Payment successful
      handle_successful_payment(bill_code, amount)
    when "2"
      # Payment pending
      handle_pending_payment(bill_code)
    when "3"
      # Payment failed
      handle_failed_payment(bill_code)
    end

    head :ok
  end
end
```

## Thread Safety

The gem is designed to be thread-safe:

```ruby
# Each client instance maintains its own configuration
threads = 10.times.map do |i|
  Thread.new do
    client = ToyyibPay::Client.new("api-key-#{i}")
    client.bills.create(...)
  end
end

threads.each(&:join)
```

## Logging

Enable logging to debug API requests:

```ruby
ToyyibPay.configure do |config|
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::DEBUG
end
```

## Development

After checking out the repo, run:

```bash
bundle install
```

Run tests:

```bash
bundle exec rspec
```

Run linter:

```bash
bundle exec rubocop
```

## Testing

The gem uses RSpec for testing with WebMock for HTTP stubbing:

```bash
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/revolutionstage/toyyibpay-ruby

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Resources

- [toyyibPay Official Website](https://toyyibpay.com)
- [toyyibPay API Documentation](https://toyyibpay.com/apireference/)
- [toyyibPay Sandbox](https://dev.toyyibpay.com)
- [Unofficial Better Documentation](https://toyyibpay-api-documentation.fajarhac.com/)

## Credits

This gem is inspired by the excellent [stripe-ruby](https://github.com/stripe/stripe-ruby) gem and follows similar patterns and best practices.

## Support

For issues related to:
- **This gem**: [Open an issue](https://github.com/revolutionstage/toyyibpay-ruby/issues)
- **toyyibPay API**: Contact toyyibPay support at https://toyyibpay.com
