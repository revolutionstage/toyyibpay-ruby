# Security Guidelines for ToyyibPay Ruby Gem

## Table of Contents

1. [Overview](#overview)
2. [Critical Vulnerabilities Addressed](#critical-vulnerabilities-addressed)
3. [Callback Verification (CRITICAL)](#callback-verification-critical)
4. [Input Validation and Sanitization](#input-validation-and-sanitization)
5. [Secure Configuration](#secure-configuration)
6. [Best Practices](#best-practices)
7. [Reporting Security Issues](#reporting-security-issues)

## Overview

This document outlines critical security considerations when integrating the ToyyibPay payment gateway into your Ruby application. **Payment systems are high-value targets for attackers**, and improper implementation can lead to:

- Financial fraud ("free shopping" attacks)
- Data breaches and PII leakage
- Compliance violations (PCI-DSS, PDPA)
- Reputational damage

## Critical Vulnerabilities Addressed

This gem has been hardened against the following vulnerability classes identified in comprehensive security audits:

### VULN-001: Callback Spoofing (CRITICAL - CVSS 9.8)

**Problem**: The ToyyibPay API does not provide HMAC signatures or cryptographic verification for payment callbacks. Without proper verification, attackers can forge "payment successful" callbacks and receive goods without paying.

**Solution**: This gem provides `ToyyibPay::CallbackVerifier` that implements the "Double-Check" pattern. **See [Callback Verification](#callback-verification-critical) below.**

### VULN-002: IDOR and Data Leakage (HIGH - CVSS 7.5)

**Problem**: Bill codes may be predictable, allowing enumeration of customer PII.

**Mitigation**:
- Never expose bill codes in public URLs without authentication
- Implement access control checks before displaying transaction data
- Use your own UUIDs as primary identifiers, store bill codes internally

### VULN-003: Input Integrity Issues (HIGH - CVSS 7.3)

**Problem**: Unsanitized inputs can lead to XSS attacks, parameter tampering, and mass assignment vulnerabilities.

**Solution**: This gem automatically sanitizes user-provided text fields (`billName`, `billDescription`) and validates critical parameters (`billPriceSetting`, `billAmount`).

### VULN-004: Configuration and Logging Risks (MEDIUM - CVSS 6.5)

**Problem**: Logging sensitive parameters (API keys, customer PII) creates data leakage risks.

**Solution**: This gem redacts sensitive parameters in logs at DEBUG level.

---

## Callback Verification (CRITICAL)

### ⚠️ NEVER Trust Callback Data Directly

The most critical vulnerability in ToyyibPay integrations is trusting callback parameters without verification. **Callbacks are NOT authenticated** - anyone can POST to your callback URL.

### ❌ INSECURE Example (DO NOT USE)

```ruby
def callback
  # VULNERABLE: Trusts status_id from untrusted POST request
  status_id = params[:status_id]

  if status_id == "1"
    order.mark_as_paid!  # ⚠️ CRITICAL VULNERABILITY
  end

  head :ok
end
```

**Attack**: An attacker can send:
```bash
curl -X POST https://yoursite.com/payments/callback \
  -d "status_id=1" \
  -d "billcode=h5bz62x1"
```

Your system will mark the order as paid without any actual payment.

### ✅ SECURE Example (Required Implementation)

```ruby
def callback
  bill_code = params[:billcode]
  order = Order.find_by(toyyibpay_bill_code: bill_code)

  return head :ok unless order

  # CRITICAL: Verify with ToyyibPay API (authoritative source)
  verifier = ToyyibPay::CallbackVerifier.new
  result = verifier.verify(
    bill_code: bill_code,
    expected_amount: (order.total * 100).to_i.to_s, # cents
    expected_status: "1"
  )

  if result.verified?
    # Now it's safe - we've confirmed with ToyyibPay
    order.mark_as_paid!(
      amount: result.amount,
      reference_no: result.reference_no,
      paid_at: result.paid_at
    )
  else
    # Log potential fraud attempt
    Rails.logger.error("Callback verification FAILED: #{result.errors}")
    SecurityMailer.suspicious_callback(order, result.errors).deliver_later
  end

  head :ok
end
```

### How CallbackVerifier Works

```ruby
# The verifier treats the callback as an untrusted "wake-up" signal
# and queries the authoritative API to verify actual payment status

result = verifier.verify(
  bill_code: "h5bz62x1",
  expected_amount: "10000",  # Amount in cents
  expected_status: "1"       # 1 = successful
)

# Verification performs:
# 1. API call to ToyyibPay.bills.transactions(bill_code)
# 2. Status verification (actual vs expected)
# 3. Amount verification (actual vs expected)
# 4. Returns result with transaction data if verified

if result.verified?
  puts result.amount         # "100.00"
  puts result.reference_no   # "TP70269027515316130721"
  puts result.paid_at        # Transaction timestamp
else
  puts result.errors         # ["Amount mismatch: ..."]
end
```

### Additional Verification Options

```ruby
# Skip amount verification (for open-price bills)
result = verifier.verify(
  bill_code: bill_code,
  expected_status: "1",
  verify_amount: false
)

# Use verify! to raise exception on failure
begin
  result = verifier.verify!(
    bill_code: bill_code,
    expected_amount: order.total_cents.to_s
  )
  order.mark_as_paid!
rescue ToyyibPay::InvalidRequestError => e
  Rails.logger.error("Verification failed: #{e.message}")
end
```

---

## Input Validation and Sanitization

### Automatic Sanitization

The gem automatically sanitizes user inputs when creating bills:

```ruby
# These fields are sanitized to prevent XSS
bill = ToyyibPay.bills.create(
  billName: "<script>alert('xss')</script>",  # Sanitized to &lt;script&gt;...
  billDescription: params[:description],      # User input sanitized
  billAmount: "10000"
)
```

### Parameter Whitelisting

**Always whitelist and hardcode critical parameters:**

```ruby
# ✅ SECURE: Hardcode critical values
def create_payment
  bill = ToyyibPay.bills.create(
    billName: "Order ##{@order.id}",
    billDescription: @order.description,
    billPriceSetting: "0",  # ⚠️ HARDCODE to prevent tampering
    billPayorInfo: "1",
    billAmount: (@order.total * 100).to_i.to_s,  # ⚠️ SERVER-SIDE calculation
    billReturnUrl: payment_return_url,
    billCallbackUrl: payment_callback_url
  )
end

# ❌ INSECURE: Passing params directly
def create_payment_insecure
  bill = ToyyibPay.bills.create(params[:bill])  # Mass assignment vulnerability!
end
```

### Critical Parameters to Hardcode

| Parameter | Why | Risk if User-Controlled |
|-----------|-----|-------------------------|
| `billPriceSetting` | Prevents "open price" tampering | User pays $1 for $1000 item |
| `billAmount` | Must be server-calculated | Amount manipulation |
| `billChargeToCustomer` | Fee handling | Fee bypass |
| `billCallbackUrl` | Callback destination | Callback hijacking |

---

## Secure Configuration

### Environment Variables

**NEVER hardcode API keys in source code:**

```ruby
# ❌ INSECURE
ToyyibPay.configure do |config|
  config.api_key = "your-secret-key"  # Hardcoded!
end

# ✅ SECURE
ToyyibPay.configure do |config|
  config.api_key = ENV["TOYYIBPAY_API_KEY"]
  config.category_code = ENV["TOYYIBPAY_CATEGORY_CODE"]
  config.sandbox = ENV["TOYYIBPAY_SANDBOX"] == "true"
end
```

### Rails Credentials (Recommended)

```bash
rails credentials:edit
```

```yaml
toyyibpay:
  api_key: <%= your_encrypted_key %>
  category_code: <%= your_category_code %>
```

```ruby
# config/initializers/toyyibpay.rb
ToyyibPay.configure do |config|
  config.api_key = Rails.application.credentials.dig(:toyyibpay, :api_key)
  config.category_code = Rails.application.credentials.dig(:toyyibpay, :category_code)
  config.sandbox = Rails.env.development?
end
```

### Logging Security

The gem automatically redacts sensitive data from logs:

```ruby
# These are redacted in logs:
# - userSecretKey
# - billEmail, billPhone, billTo
# - billpayorEmail, billpayorPhone

ToyyibPay.configure do |config|
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::INFO  # Use INFO in production, DEBUG only for troubleshooting
end

# Log output shows: "Request params: {billName: 'Order #1', userSecretKey: '[REDACTED]'}"
```

---

## Best Practices

### 1. Use HTTPS Everywhere

```ruby
# Enforce HTTPS in production
config.force_ssl = true  # Rails

# Validate callback URLs use HTTPS
def payment_callback_url
  url = "#{request.base_url}/payments/callback"
  raise "Callback URL must use HTTPS" unless url.start_with?("https://")
  url
end
```

### 2. Implement Idempotency

Callbacks may be sent multiple times. Use database constraints:

```ruby
class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :order, null: false
      t.string :toyyibpay_reference_no, null: false
      t.timestamps
    end

    # Prevent duplicate processing
    add_index :payments, :toyyibpay_reference_no, unique: true
  end
end

def callback
  # ...verification...
  if result.verified?
    Payment.create!(
      order: order,
      toyyibpay_reference_no: result.reference_no,
      amount: result.amount
    )
  end
rescue ActiveRecord::RecordNotUnique
  Rails.logger.info("Duplicate callback ignored")
end
```

### 3. Rate Limiting

Protect your callback endpoint from abuse:

```ruby
# Using rack-attack
Rack::Attack.throttle("payments/callback", limit: 10, period: 60) do |req|
  req.ip if req.path == "/payments/callback"
end
```

### 4. Access Control for Bill Data

Never expose bill queries without authentication:

```ruby
# ❌ INSECURE
def show
  @bill_code = params[:bill_code]
  @transactions = ToyyibPay.bills.transactions(@bill_code)  # Public access!
end

# ✅ SECURE
def show
  @order = current_user.orders.find(params[:id])  # Auth check
  @transactions = ToyyibPay.bills.transactions(@order.toyyibpay_bill_code)
end
```

### 5. CSRF Protection

The gem's example disables CSRF for callbacks (required for external POSTs):

```ruby
skip_before_action :verify_authenticity_token, only: [:callback]
```

**This is safe ONLY if you implement callback verification.** Without verification, this creates a CSRF vulnerability.

### 6. Monitor and Alert

```ruby
# Alert on verification failures (potential fraud)
if result.failed?
  SlackNotifier.notify(
    channel: "#security",
    message: "⚠️ Payment callback verification failed for order #{order.id}: #{result.errors}"
  )
end

# Monitor for suspicious patterns
if order.callback_verification_failures > 3
  order.lock!
  SecurityTeam.alert(order)
end
```

---

## Compliance Considerations

### PCI-DSS

- ✅ The gem does not handle card data directly (ToyyibPay does)
- ✅ API keys are treated as sensitive authentication data
- ⚠️ Merchants must ensure TLS 1.2+ is enforced
- ⚠️ Callback verification is required for Requirement 6 (Secure Systems)

### PDPA (Malaysian Personal Data Protection Act)

The gem collects customer PII (`billTo`, `billEmail`, `billPhone`):

- Only collect PII necessary for transactions
- Implement retention policies (delete old transaction data)
- Provide customer data access/deletion mechanisms
- Log access to PII for audit trails

### GDPR (if applicable)

For EU customers:

- Obtain consent before processing
- Implement right-to-erasure
- Minimize data retention
- Ensure ToyyibPay's data processing agreement

---

## Security Checklist

Before going to production:

- [ ] Callback verification implemented using `CallbackVerifier`
- [ ] Amount verification enabled (`verify_amount: true`)
- [ ] API keys stored in environment variables or encrypted credentials
- [ ] HTTPS enforced for callback URLs
- [ ] `billPriceSetting` hardcoded to `"0"` for fixed-price bills
- [ ] `billAmount` calculated server-side, never from user input
- [ ] Database unique constraint on payment reference numbers
- [ ] Rate limiting enabled on callback endpoint
- [ ] Logging level set to INFO in production
- [ ] Monitoring/alerting configured for verification failures
- [ ] Access control implemented for transaction queries
- [ ] Regular security updates (`bundle update`)

---

## Reporting Security Issues

**Do not report security vulnerabilities through public GitHub issues.**

Please report security vulnerabilities privately to: **developers@kintsugidesign.com**

Include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to respond within 48 hours and provide fixes for critical issues within 7 days.

---

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PCI-DSS Requirements](https://www.pcisecuritystandards.org/)
- [Malaysian PDPA Guidelines](https://www.pdp.gov.my/)
- [ToyyibPay API Documentation](https://toyyibpay.com/apireference/)

---

**Last Updated**: 2025-11-24
**Version**: 1.0.0
