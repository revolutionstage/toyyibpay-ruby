#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for ToyyibPay gem
#
# To run this example:
# 1. Set your API credentials as environment variables:
#    export TOYYIBPAY_API_KEY="your-secret-key"
#    export TOYYIBPAY_CATEGORY_CODE="your-category-code"
# 2. Run: ruby examples/basic_usage.rb

require "bundler/setup"
require "toyyibpay"

# Configure ToyyibPay
ToyyibPay.configure do |config|
  config.api_key = ENV["TOYYIBPAY_API_KEY"]
  config.category_code = ENV["TOYYIBPAY_CATEGORY_CODE"]
  config.sandbox = true # Use sandbox for testing
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::INFO
end

puts "=" * 80
puts "ToyyibPay Ruby Gem - Basic Usage Example"
puts "=" * 80
puts

# Example 1: List available banks
puts "1. Listing available banks..."
puts "-" * 80
banks = ToyyibPay.banks.all
puts "Found #{banks.length} banks"
banks.first(3).each do |bank|
  puts "  - #{bank['bankName']} (ID: #{bank['bankID']})"
end
puts

# Example 2: Create a category
puts "2. Creating a category..."
puts "-" * 80
category = ToyyibPay.categories.create(
  catname: "Example Products",
  catdescription: "Category for example product sales"
)
puts "Category created: #{category[0]['CategoryCode']}"
puts

# Example 3: Create a bill
puts "3. Creating a bill..."
puts "-" * 80
bill = ToyyibPay.bills.create(
  billName: "Example Invoice #001",
  billDescription: "Payment for services rendered",
  billPriceSetting: "0", # Fixed price
  billPayorInfo: "1",    # Payor info optional
  billAmount: "10000",   # RM 100.00
  billReturnUrl: "https://example.com/payment/return",
  billCallbackUrl: "https://example.com/payment/callback",
  billPaymentChannel: "2", # Both FPX and Credit Card
  billExternalReferenceNo: "ORDER-#{Time.now.to_i}"
)
bill_code = bill[0]["BillCode"]
puts "Bill created: #{bill_code}"
puts

# Example 4: Get payment URL
puts "4. Getting payment URL..."
puts "-" * 80
payment_url = ToyyibPay.bills.payment_url(bill_code)
puts "Payment URL: #{payment_url}"
puts "Share this URL with your customer to complete payment"
puts

# Example 5: Check bill transactions
puts "5. Checking bill transactions..."
puts "-" * 80
transactions = ToyyibPay.bills.transactions(bill_code)
puts "Found #{transactions.length} transaction(s)"
puts

# Example 6: Using a separate client instance
puts "6. Using a separate client instance..."
puts "-" * 80
client = ToyyibPay::Client.new(
  ENV["TOYYIBPAY_API_KEY"],
  category_code: ENV["TOYYIBPAY_CATEGORY_CODE"],
  sandbox: true
)
packages = client.packages.all
puts "Found #{packages.length} package(s)"
puts

puts "=" * 80
puts "Example completed successfully!"
puts "=" * 80
