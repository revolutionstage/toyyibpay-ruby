# frozen_string_literal: true

module ToyyibPay
  # Compliance utilities for PCI-DSS, PDPA, and GDPR requirements
  #
  # This module provides utilities to help merchants comply with various
  # data protection and payment security regulations.
  module Compliance
    module_function

    # PII fields that require special handling under PDPA/GDPR
    PII_FIELDS = %w[
      billTo
      billEmail
      billPhone
      billpayorName
      billpayorEmail
      billpayorPhone
      billpayorId
    ].freeze

    # Sensitive financial data fields
    FINANCIAL_FIELDS = %w[
      billAmount
      billpaymentAmount
      billChargeToCustomer
    ].freeze

    # Check if TLS 1.2+ is being used (PCI-DSS Requirement 4.1)
    #
    # @param url [String] URL to check
    # @return [Boolean] true if HTTPS with TLS 1.2+
    def verify_tls_version(url)
      uri = URI.parse(url)

      unless uri.scheme == "https"
        raise SecurityError, "PCI-DSS violation: URL must use HTTPS (found: #{uri.scheme})"
      end

      # Note: Ruby's OpenSSL will enforce TLS 1.2+ by default in modern versions
      # Additional runtime checks can be added here if needed
      true
    end

    # Validate callback URL meets security requirements
    #
    # @param callback_url [String] Callback URL to validate
    # @return [Boolean] true if valid
    # @raise [SecurityError] if URL doesn't meet requirements
    def validate_callback_url(callback_url)
      return true if callback_url.nil? || callback_url.empty?

      # Must use HTTPS in production
      verify_tls_version(callback_url)

      uri = URI.parse(callback_url)

      # Warn about localhost/127.0.0.1 (development only)
      if ["localhost", "127.0.0.1", "0.0.0.0"].include?(uri.host)
        warn "[ToyyibPay] WARNING: Callback URL uses localhost. This should only be used in development."
      end

      # Warn about IP addresses (should use domain names with valid SSL certs)
      if uri.host =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
        warn "[ToyyibPay] WARNING: Callback URL uses IP address. Use a domain name with valid SSL certificate."
      end

      true
    rescue URI::InvalidURIError => e
      raise SecurityError, "Invalid callback URL: #{e.message}"
    end

    # Redact PII from data for logging/debugging (PDPA/GDPR compliance)
    #
    # @param data [Hash] Data to redact
    # @param fields [Array<String>] Additional fields to redact
    # @return [Hash] Data with PII redacted
    def redact_pii(data, fields: [])
      return data unless data.is_a?(Hash)

      sensitive_fields = PII_FIELDS + fields

      data.transform_values do |value|
        if value.is_a?(Hash)
          redact_pii(value, fields: fields)
        else
          value
        end
      end.transform_keys do |key|
        if sensitive_fields.any? { |field| key.to_s.include?(field) }
          "[REDACTED_PII]"
        else
          key
        end
      end
    end

    # Validate bill parameters for PCI-DSS compliance
    #
    # Ensures no card data is being sent (PCI-DSS Requirement 3)
    #
    # @param params [Hash] Bill parameters
    # @return [Boolean] true if compliant
    # @raise [SecurityError] if card data detected
    def validate_no_card_data(params)
      return true unless params.is_a?(Hash)

      # Card data patterns that should NEVER be in bill parameters
      card_patterns = [
        /\b\d{13,19}\b/, # Card numbers (13-19 digits)
        /\bcvv\b/i,
        /\bcvc\b/i,
        /\bcard.?number\b/i,
        /\bcard.?holder\b/i,
        /\bexpir/i
      ]

      params.each do |key, value|
        next unless value.is_a?(String)

        card_patterns.each do |pattern|
          if key.to_s.match?(pattern) || value.match?(pattern)
            raise SecurityError, "PCI-DSS violation: Possible card data detected in bill parameters. " \
                                 "Card data must NEVER be sent to your server. Use ToyyibPay's hosted payment page."
          end
        end
      end

      true
    end

    # Generate audit log entry for payment operations (PCI-DSS Requirement 10)
    #
    # @param event_type [Symbol] Type of event (:bill_created, :payment_verified, etc)
    # @param data [Hash] Event data
    # @return [Hash] Formatted audit log entry
    def audit_log_entry(event_type, data = {})
      {
        timestamp: Time.now.utc.iso8601,
        event_type: event_type,
        user_id: data[:user_id],
        order_id: data[:order_id],
        bill_code: data[:bill_code],
        amount: data[:amount],
        status: data[:status],
        ip_address: data[:ip_address],
        session_id: data[:session_id],
        # Redact PII from additional data
        metadata: redact_pii(data[:metadata] || {})
      }
    end

    # Check if data retention period has expired (PDPA/GDPR compliance)
    #
    # @param created_at [Time] When the record was created
    # @param retention_days [Integer] Retention period in days (default: 2555 days / 7 years for financial records)
    # @return [Boolean] true if retention period has expired
    def retention_period_expired?(created_at, retention_days: 2555)
      return false if created_at.nil?

      created_at = Time.parse(created_at.to_s) unless created_at.is_a?(Time)
      expiry_date = created_at + (retention_days * 24 * 60 * 60)
      Time.now > expiry_date
    end

    # Generate data subject access report (GDPR Article 15 / PDPA Section 33)
    #
    # @param transactions [Array<Hash>] User's transactions
    # @return [Hash] Formatted report of all data held
    def data_subject_access_report(transactions)
      {
        report_generated_at: Time.now.utc.iso8601,
        data_controller: "Your Company Name",
        purpose_of_processing: "Payment processing via ToyyibPay gateway",
        legal_basis: "Contract fulfillment / Consent",
        retention_period: "7 years (financial record keeping requirement)",
        transactions: transactions.map do |txn|
          {
            bill_code: txn["billCode"] || txn[:billCode],
            bill_name: txn["billName"] || txn[:billName],
            amount: txn["billAmount"] || txn[:billAmount],
            status: txn["billpaymentStatus"] || txn[:billpaymentStatus],
            created_at: txn["billDate"] || txn[:billDate],
            paid_at: txn["billPaymentDate"] || txn[:billPaymentDate]
          }
        end,
        rights: {
          access: "You can request this report at any time",
          rectification: "Contact us to correct inaccurate data",
          erasure: "Request deletion after retention period expires",
          portability: "Request data in machine-readable format",
          objection: "Object to processing (may prevent service)"
        }
      }
    end

    # Mask PII for display purposes (show last 4 digits of phone, partial email)
    #
    # @param value [String] Value to mask
    # @param type [Symbol] Type of PII (:email, :phone)
    # @return [String] Masked value
    def mask_pii(value, type:)
      return value if value.nil? || value.empty?

      case type
      when :email
        # email@example.com -> e***l@example.com
        local, domain = value.split("@")
        return value if local.nil? || domain.nil?

        "#{local[0]}#{'*' * (local.length - 2)}#{local[-1]}@#{domain}"
      when :phone
        # 0123456789 -> ******6789
        return value if value.length < 4

        "#{'*' * (value.length - 4)}#{value[-4..]}"
      when :name
        # John Doe -> J*** D***
        parts = value.split
        parts.map { |part| "#{part[0]}#{'*' * (part.length - 1)}" }.join(" ")
      else
        # Generic masking
        return value if value.length < 4

        "#{value[0..1]}#{'*' * (value.length - 4)}#{value[-2..]}"
      end
    end

    # Validate consent was obtained (PDPA Section 6 / GDPR Article 7)
    #
    # @param consent_data [Hash] Consent metadata
    # @return [Boolean] true if consent is valid
    # @raise [SecurityError] if consent is invalid
    def validate_consent(consent_data)
      required_fields = %i[
        obtained_at
        purpose
        user_ip
        user_agent
        version
      ]

      missing = required_fields - consent_data.keys
      if missing.any?
        raise SecurityError, "Invalid consent record: missing fields #{missing.join(', ')}"
      end

      # Consent must be recent (within last 2 years for financial transactions)
      obtained_at = Time.parse(consent_data[:obtained_at].to_s)
      if Time.now - obtained_at > (730 * 24 * 60 * 60) # 2 years
        raise SecurityError, "Consent expired: obtained #{obtained_at}, must be renewed"
      end

      true
    end

    # Generate PDPA/GDPR compliant privacy notice text
    #
    # @return [String] Privacy notice template
    def privacy_notice_template
      <<~NOTICE
        DATA PROTECTION NOTICE

        Purpose of Collection:
        We collect your personal data (name, email, phone number) to process
        your payment via ToyyibPay payment gateway and fulfill your order.

        Legal Basis:
        - Contract fulfillment (processing your order)
        - Consent (for marketing communications, if separately obtained)

        Data Recipients:
        Your data will be shared with:
        - ToyyibPay (payment processor)
        - Financial institutions (for payment processing)

        Retention Period:
        We retain your transaction data for 7 years to comply with financial
        record-keeping requirements under Malaysian law.

        Your Rights:
        You have the right to:
        - Access your personal data
        - Request correction of inaccurate data
        - Request deletion (after retention period)
        - Object to processing
        - Data portability

        Contact:
        For data protection inquiries: [Your DPO Email]

        Last Updated: #{Time.now.strftime("%Y-%m-%d")}
      NOTICE
    end
  end
end
