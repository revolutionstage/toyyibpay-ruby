# Compliance Guide: PCI-DSS, PDPA & GDPR

## Overview

This guide helps you implement ToyyibPay in compliance with:

- **PCI-DSS v4.0** (Payment Card Industry Data Security Standard)
- **PDPA** (Malaysian Personal Data Protection Act 2010)
- **GDPR** (EU General Data Protection Regulation)

## Table of Contents

1. [Quick Start Compliance Checklist](#quick-start-compliance-checklist)
2. [PCI-DSS Compliance](#pci-dss-compliance)
3. [PDPA Compliance (Malaysia)](#pdpa-compliance-malaysia)
4. [GDPR Compliance (EU)](#gdpr-compliance-eu)
5. [Implementation Examples](#implementation-examples)
6. [Audit Logging](#audit-logging)
7. [Data Retention](#data-retention)
8. [Incident Response](#incident-response)

---

## Quick Start Compliance Checklist

### Pre-Launch Requirements

- [ ] **Audit logging configured** (see [Audit Logging](#audit-logging))
- [ ] **Data retention policy implemented** (7 years for financial records)
- [ ] **Privacy policy published** on your website
- [ ] **Cookie consent banner** implemented (if using analytics)
- [ ] **HTTPS enforced** on all pages (PCI-DSS Requirement 4.1)
- [ ] **Callback verification enabled** (prevents fraud)
- [ ] **No card data** stored in your database (PCI-DSS Requirement 3)
- [ ] **Customer consent** obtained before processing PII
- [ ] **Data Processing Agreement** signed with ToyyibPay
- [ ] **Security incident response plan** documented

### Ongoing Requirements

- [ ] **Audit logs reviewed** monthly for suspicious activity
- [ ] **Data retention cleanup** run quarterly
- [ ] **Privacy policy updated** when processing changes
- [ ] **Customer data access requests** handled within 30 days (PDPA) or 1 month (GDPR)
- [ ] **Security patches applied** to gem and dependencies
- [ ] **Staff training** on data protection annually

---

## PCI-DSS Compliance

### What is PCI-DSS?

The Payment Card Industry Data Security Standard applies to **any organization that stores, processes, or transmits cardholder data**. Even though ToyyibPay handles the actual card processing, your integration must still meet certain requirements.

### Your Responsibility Level

Since you use ToyyibPay's hosted payment page and **do not handle raw card data**, you qualify for **SAQ A** (Self-Assessment Questionnaire A) - the simplest compliance level.

### Key Requirements

#### Requirement 1-2: Network Security

✅ **Automatically compliant** - ToyyibPay handles card processing on their secure network.

#### Requirement 3: Protect Stored Cardholder Data

**Critical**: NEVER store:
- Full card numbers (PAN)
- CVV/CVC codes
- Card expiry dates
- Cardholder names (in relation to card data)

```ruby
# ✅ CORRECT: No card data stored
Order.create(
  user: current_user,
  total: 100.00,
  toyyibpay_bill_code: bill_code  # Only store the bill code
)

# ❌ WRONG: Storing card data
Order.create(
  card_number: "4111111111111111",  # PCI-DSS VIOLATION!
  cvv: "123"                         # NEVER DO THIS!
)
```

**Built-in Protection**: The gem validates that no card data is sent:

```ruby
# This will raise SecurityError if card patterns detected
ToyyibPay.bills.create(
  billName: "Order #123",
  billDescription: "Card: 4111111111111111"  # ⚠️ ERROR raised!
)
```

#### Requirement 4: Encrypt Transmission

**Required**: All API calls and callbacks must use HTTPS (TLS 1.2+).

```ruby
# ✅ CORRECT: HTTPS enforced
config.force_ssl = true  # In production.rb

# Gem automatically validates callback URLs
ToyyibPay.bills.create(
  billCallbackUrl: "https://yoursite.com/callback"  # ✅ Valid
  # billCallbackUrl: "http://yoursite.com/callback"  # ❌ Error!
)
```

#### Requirement 6: Secure Systems

**Required**: Use callback verification to prevent payment fraud.

See [SECURITY.md](SECURITY.md) for implementation.

#### Requirement 10: Track and Monitor Access

**Required**: Implement audit logging for all payment operations.

```ruby
# Configure audit logging
ToyyibPay::AuditLogger.configure do |config|
  config.logger = Logger.new(Rails.root.join("log", "toyyibpay_audit.log"))
  config.enabled = Rails.env.production?
end

# Logging happens automatically, or manually:
ToyyibPay::AuditLogger.log_payment_verified(
  bill_code: "abc123",
  amount: "10000",
  user_id: current_user.id,
  ip_address: request.remote_ip
)
```

#### Requirement 12: Information Security Policy

**Required**: Document your payment processing procedures. See [templates](#policy-templates) below.

---

## PDPA Compliance (Malaysia)

### What is PDPA?

The Malaysian Personal Data Protection Act 2010 regulates the processing of personal data in commercial transactions.

### Personal Data Collected

When using ToyyibPay, you collect:

- **Name** (`billTo`, `billpayorName`)
- **Email** (`billEmail`, `billpayorEmail`)
- **Phone** (`billPhone`, `billpayorPhone`)
- **Transaction data** (amount, date, status)

### Seven Principles of PDPA

#### 1. General Principle (Section 5)

Process data **lawfully and fairly**.

```ruby
# ✅ CORRECT: Clear purpose stated
def checkout
  # Show consent notice BEFORE collecting data
  render :consent_required unless current_user.consented_to_payment_processing?

  create_payment if current_user.consented?
end
```

#### 2. Notice and Choice Principle (Section 7)

**Required**: Inform users BEFORE collecting their data.

```erb
<!-- In your checkout form -->
<form>
  <!-- ... payment fields ... -->

  <div class="privacy-notice">
    <p>
      We will share your name, email, and phone number with ToyyibPay
      (our payment processor) to complete your transaction. Your data
      will be retained for 7 years as required by Malaysian law.
    </p>
    <p>
      <a href="/privacy-policy">Read our full Privacy Policy</a>
    </p>
  </div>

  <label>
    <input type="checkbox" name="consent" required>
    I consent to the processing of my personal data
  </label>
</form>
```

Store consent:

```ruby
class Payment < ApplicationRecord
  # Migration: add consent fields
  # t.datetime :consent_obtained_at
  # t.string :consent_ip_address
  # t.text :consent_user_agent
  # t.string :consent_version

  def record_consent(request)
    self.consent_obtained_at = Time.current
    self.consent_ip_address = request.remote_ip
    self.consent_user_agent = request.user_agent
    self.consent_version = "2024-01"  # Version your privacy policy
    save!
  end
end
```

#### 3. Disclosure Principle (Section 8)

**Required**: Only disclose to authorized parties (ToyyibPay).

✅ **Automatically compliant** - gem only sends data to ToyyibPay API.

#### 4. Security Principle (Section 9)

**Required**: Protect personal data from unauthorized access.

```ruby
# ✅ Implement these security measures:

# 1. Encrypt database
config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]

# 2. Mask PII in logs
ToyyibPay::Compliance.mask_pii("customer@email.com", type: :email)
# => "c*********r@email.com"

# 3. Use secure sessions
config.session_store :cookie_store,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax

# 4. Enable audit logging (tracks access)
ToyyibPay::AuditLogger.log_data_access(
  user_id: admin_user.id,
  accessed_user_id: customer.id,
  ip_address: request.remote_ip
)
```

#### 5. Retention Principle (Section 10)

**Required**: Don't keep data longer than necessary.

**Default**: 7 years for financial records (Companies Act 2016, Section 245).

```ruby
# Check if data should be deleted
retention = ToyyibPay::DataRetention.new
payment = Payment.find(params[:id])

if retention.should_delete?(payment.created_at, record_type: :financial_records)
  # After 7 years, anonymize customer data
  payment.update(
    customer_name: "[DELETED]",
    customer_email: "[DELETED]",
    customer_phone: "[DELETED]"
  )

  # Log the deletion
  ToyyibPay::AuditLogger.log_data_deletion(
    payment_id: payment.id,
    deleted_by: current_admin.id
  )
end
```

#### 6. Data Integrity Principle (Section 11)

**Required**: Ensure data is accurate.

```ruby
# ✅ Built-in validation
ToyyibPay::Util.sanitize_bill_params(params)  # Validates formats

# Allow customers to update their data
def update_customer_info
  authorize! # Ensure user can only update their own data
  current_user.update!(customer_params)
  flash[:success] = "Your information has been updated"
end
```

#### 7. Access Principle (Section 12)

**Required**: Allow users to access their data.

```ruby
# Data Subject Access Request (DSAR) endpoint
class DataAccessRequestsController < ApplicationController
  def create
    # Generate report of all data held
    payments = current_user.payments.includes(:orders)

    report = ToyyibPay::Compliance.data_subject_access_report(
      payments.map(&:attributes)
    )

    # Email the report
    DataAccessMailer.send_report(current_user, report).deliver_later

    # Log the access
    ToyyibPay::AuditLogger.log_data_access(
      user_id: current_user.id,
      action: "data_access_request",
      ip_address: request.remote_ip
    )

    flash[:success] = "Your data access report will be emailed within 24 hours"
  end
end
```

### PDPA Penalties

- **First offense**: Fine up to RM 250,000 or imprisonment up to 2 years
- **Subsequent offense**: Fine up to RM 500,000 or imprisonment up to 3 years

---

## GDPR Compliance (EU)

### When Does GDPR Apply?

If you process data of **EU residents**, even if your business is in Malaysia.

### Key Differences from PDPA

| Requirement | PDPA | GDPR |
|-------------|------|------|
| **Data access request response time** | 21-30 days | 1 month |
| **Consent** | Implied or explicit | Must be explicit |
| **Right to erasure** | Limited | Absolute (with exceptions) |
| **Data portability** | Not required | Required |
| **Fines** | Up to RM 500k | Up to €20M or 4% of revenue |

### GDPR-Specific Requirements

#### Right to Erasure ("Right to be Forgotten")

```ruby
class DataDeletionRequestsController < ApplicationController
  def create
    user = current_user

    # Check if retention period allows deletion
    retention = ToyyibPay::DataRetention.new
    recent_payment = user.payments.order(created_at: :desc).first

    if recent_payment && !retention.should_delete?(recent_payment.created_at)
      expiry = retention.expiry_date(recent_payment.created_at)
      flash[:error] = "Your data must be retained until #{expiry.strftime('%Y-%m-%d')} " \
                     "for financial record-keeping compliance. " \
                     "We can anonymize your personal details while keeping transaction records."
      return redirect_to settings_path
    end

    # Anonymize personal data
    user.payments.each do |payment|
      anonymized = retention.anonymize_customer_data(payment.attributes)
      payment.update!(anonymized)
    end

    # Log deletion
    ToyyibPay::AuditLogger.log_data_deletion(
      user_id: user.id,
      deleted_at: Time.current,
      ip_address: request.remote_ip
    )

    user.destroy!
    flash[:success] = "Your account and personal data have been deleted"
    redirect_to root_path
  end
end
```

#### Data Portability

```ruby
class DataExportController < ApplicationController
  def create
    payments = current_user.payments

    # Export in machine-readable format (JSON)
    export_data = {
      exported_at: Time.current.iso8601,
      format_version: "1.0",
      user: {
        id: current_user.id,
        email: current_user.email,
        created_at: current_user.created_at
      },
      payments: payments.map do |p|
        {
          bill_code: p.toyyibpay_bill_code,
          amount: p.amount,
          status: p.status,
          created_at: p.created_at,
          paid_at: p.paid_at
        }
      end
    }

    send_data export_data.to_json,
      filename: "my-data-#{Date.today}.json",
      type: "application/json"
  end
end
```

---

## Implementation Examples

### Complete Compliant Checkout Flow

```ruby
class CheckoutController < ApplicationController
  def new
    @order = Order.find(params[:order_id])

    # Show consent form if not already obtained
    unless current_user.payment_consent_current?
      redirect_to new_consent_path(return_to: checkout_path(@order))
    end
  end

  def create
    @order = Order.find(params[:order_id])

    # Verify consent
    unless current_user.payment_consent_current?
      flash[:error] = "Consent required"
      return redirect_to new_consent_path
    end

    # Create bill with audit trail
    bill = ToyyibPay.bills.create(
      billName: "Order ##{@order.id}",
      billDescription: @order.description,
      billPriceSetting: "0",  # Hardcoded
      billAmount: (@order.total * 100).to_i.to_s,
      billCallbackUrl: payment_callback_url,
      billReturnUrl: payment_return_url(@order.id),

      # Audit fields (not sent to API, used by gem)
      _audit_user_id: current_user.id,
      _audit_ip_address: request.remote_ip
    )

    # Store bill code
    @order.update!(
      toyyibpay_bill_code: bill[0]["BillCode"],
      payment_initiated_at: Time.current,
      payment_initiated_ip: request.remote_ip
    )

    # Redirect to payment page
    redirect_to ToyyibPay.bills.payment_url(bill[0]["BillCode"]), allow_other_host: true

  rescue ToyyibPay::SecurityError => e
    # PCI-DSS or security validation failed
    Rollbar.error(e, user_id: current_user.id)
    flash[:error] = "Payment initialization failed. Please contact support."
    redirect_to order_path(@order)
  end
end
```

### Consent Management

```ruby
class ConsentsController < ApplicationController
  def new
    @return_to = params[:return_to]
  end

  def create
    consent = current_user.consents.create!(
      purpose: "payment_processing",
      obtained_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      version: "2024-01",  # Version your privacy policy
      expires_at: 2.years.from_now
    )

    # Validate consent
    ToyyibPay::Compliance.validate_consent(
      obtained_at: consent.obtained_at,
      purpose: consent.purpose,
      user_ip: consent.ip_address,
      user_agent: consent.user_agent,
      version: consent.version
    )

    # Log consent
    ToyyibPay::AuditLogger.log_consent(
      user_id: current_user.id,
      consent_id: consent.id,
      purpose: consent.purpose,
      ip_address: request.remote_ip
    )

    redirect_to params[:return_to] || root_path
  end
end
```

---

## Audit Logging

### Setup

```ruby
# config/initializers/toyyibpay.rb
ToyyibPay::AuditLogger.configure do |config|
  # Separate audit log file (required for PCI-DSS)
  config.logger = Logger.new(
    Rails.root.join("log", "toyyibpay_audit.log"),
    10,           # Keep 10 old files
    10.megabytes  # Rotate after 10MB
  )

  config.enabled = true
  config.log_level = :info
end
```

### What Gets Logged

The gem automatically logs:
- ✅ Bill creation (`log_bill_created`)
- ✅ Payment verification (`log_payment_verified`)
- ✅ Verification failures (`log_verification_failed`)
- ✅ Callback received (`log_callback_received`)

You should manually log:
- Data access requests
- Data deletion requests
- Consent obtained/withdrawn
- Administrative actions

### Log Format

```json
{
  "timestamp": "2024-11-26T10:30:00Z",
  "event_type": "payment_verified",
  "user_id": 123,
  "order_id": 456,
  "bill_code": "abc123xyz",
  "amount": "10000",
  "status": "success",
  "ip_address": "192.168.1.1",
  "action": "verify_payment",
  "severity": "info"
}
```

### Log Retention

**PCI-DSS Requirement 10.5**: Retain audit logs for at least 1 year.

```ruby
# Scheduled job (daily)
class AuditLogCleanupJob < ApplicationJob
  def perform
    log_file = Rails.root.join("log", "toyyibpay_audit.log")

    # Archive logs older than 1 year
    cutoff_date = 1.year.ago

    # Implementation depends on your log management system
    # Consider using log rotation and archival tools
  end
end
```

---

## Data Retention

### Retention Periods

```ruby
ToyyibPay::DataRetention::RETENTION_PERIODS
# => {
#   financial_records: 2555,  # 7 years
#   marketing_consent: 730,    # 2 years
#   abandoned_carts: 90,       # 90 days
#   session_data: 30,          # 30 days
#   logs: 365                  # 1 year
# }
```

### Cleanup Job

```ruby
# app/jobs/data_retention_cleanup_job.rb
class DataRetentionCleanupJob < ApplicationJob
  queue_as :low_priority

  def perform
    retention = ToyyibPay::DataRetention.new

    # Anonymize old payments (keep financial records)
    Payment.where("created_at < ?", 7.years.ago).find_each do |payment|
      if retention.should_delete?(payment.created_at)
        anonymized = retention.anonymize_customer_data(payment.attributes)
        payment.update!(anonymized)

        ToyyibPay::AuditLogger.log_data_deletion(
          payment_id: payment.id,
          reason: "retention_period_expired",
          deleted_at: Time.current
        )
      end
    end

    # Delete abandoned carts
    Cart.where("created_at < ?", 90.days.ago).find_each(&:destroy!)

    # Delete old session data
    Session.where("created_at < ?", 30.days.ago).delete_all
  end
end

# Schedule it
# config/schedule.rb (using whenever gem)
every 1.week, at: "2:00 am" do
  runner "DataRetentionCleanupJob.perform_later"
end
```

---

## Policy Templates

### Privacy Policy Template

See: `ToyyibPay::Compliance.privacy_notice_template`

### Data Processing Agreement

Required under PDPA Section 40 and GDPR Article 28.

**Action Required**: Sign a Data Processing Agreement with ToyyibPay confirming:
- ToyyibPay acts as your **data processor**
- You remain the **data controller**
- ToyyibPay will process data only per your instructions
- ToyyibPay implements appropriate security measures
- Data breach notification procedures

Contact ToyyibPay support for their DPA template.

---

## Incident Response

### Security Breach Procedure

**PDPA Section 6A**: Notify authorities within **72 hours** of becoming aware of a breach.

```ruby
# app/services/security_incident_notifier.rb
class SecurityIncidentNotifier
  def self.notify_breach(incident_type:, affected_users:, description:)
    # 1. Log the incident
    Rails.logger.fatal("[SECURITY BREACH] #{incident_type}: #{description}")

    # 2. Notify internal team
    SecurityMailer.breach_notification(
      type: incident_type,
      affected_count: affected_users.count,
      description: description
    ).deliver_now

    # 3. Notify authorities (if required)
    if requires_authority_notification?(affected_users.count)
      notify_pdpc(incident_type, affected_users, description)
    end

    # 4. Notify affected users
    affected_users.find_each do |user|
      UserMailer.security_breach_notice(user, incident_type).deliver_later
    end
  end

  def self.requires_authority_notification?(affected_count)
    # PDPA: Notify if likely to result in "significant harm"
    affected_count > 50 || involves_sensitive_data?
  end

  def self.notify_pdpc(type, users, description)
    # Contact: complaints@pdp.gov.my
    # Include: nature of breach, affected individuals, remedial actions
  end
end
```

---

## Compliance Checklist Summary

### Before Launch

- [ ] Privacy policy published
- [ ] Cookie consent implemented
- [ ] Consent collection mechanism
- [ ] Audit logging enabled
- [ ] Data retention job scheduled
- [ ] HTTPS enforced everywhere
- [ ] DPA signed with ToyyibPay
- [ ] Incident response plan documented

### Quarterly

- [ ] Run data retention cleanup
- [ ] Review audit logs for anomalies
- [ ] Test data access request process
- [ ] Update dependencies (`bundle update`)

### Annually

- [ ] Review and update privacy policy
- [ ] Staff data protection training
- [ ] Security assessment
- [ ] Validate data retention compliance

---

**Need help?** Contact: developers@kintsugidesign.com

**Last Updated**: 2024-11-26
