# frozen_string_literal: true

module ToyyibPay
  # Data retention utilities for PDPA/GDPR compliance
  #
  # Helps manage customer data lifecycle and implement data retention policies
  # required by Malaysian PDPA and EU GDPR regulations.
  #
  # @example Check if data should be deleted
  #   retention = ToyyibPay::DataRetention.new
  #   if retention.should_delete?(payment.created_at)
  #     retention.delete_customer_data(payment)
  #   end
  class DataRetention
    # Default retention periods (in days)
    RETENTION_PERIODS = {
      financial_records: 2555,    # 7 years (Malaysian financial record requirement)
      marketing_consent: 730,      # 2 years
      abandoned_carts: 90,         # 90 days
      session_data: 30,            # 30 days
      logs: 365                    # 1 year
    }.freeze

    attr_reader :config

    # Initialize data retention manager
    #
    # @param retention_days [Integer] Custom retention period in days
    def initialize(retention_days: RETENTION_PERIODS[:financial_records])
      @retention_days = retention_days
    end

    # Check if record should be deleted based on retention policy
    #
    # @param created_at [Time, String] When the record was created
    # @param record_type [Symbol] Type of record (:financial_records, :marketing_consent, etc)
    # @return [Boolean] true if record should be deleted
    def should_delete?(created_at, record_type: :financial_records)
      return false if created_at.nil?

      retention_days = RETENTION_PERIODS[record_type] || @retention_days
      ToyyibPay::Compliance.retention_period_expired?(created_at, retention_days: retention_days)
    end

    # Calculate expiry date for a record
    #
    # @param created_at [Time] When the record was created
    # @param record_type [Symbol] Type of record
    # @return [Time] When the record expires
    def expiry_date(created_at, record_type: :financial_records)
      retention_days = RETENTION_PERIODS[record_type] || @retention_days
      created_at + (retention_days * 24 * 60 * 60)
    end

    # Get fields that should be redacted (but not deleted) for anonymization
    #
    # Under GDPR "right to erasure", financial records may need to be kept
    # for legal compliance, but PII can be anonymized.
    #
    # @return [Array<String>] Fields to redact
    def pii_fields_for_anonymization
      ToyyibPay::Compliance::PII_FIELDS
    end

    # Anonymize customer data while keeping transaction record
    #
    # @param data [Hash] Data to anonymize
    # @return [Hash] Anonymized data
    def anonymize_customer_data(data)
      anonymized = data.dup

      pii_fields_for_anonymization.each do |field|
        if anonymized[field] || anonymized[field.to_sym]
          key = anonymized[field] ? field : field.to_sym
          anonymized[key] = "[DELETED_#{Time.now.to_i}]"
        end
      end

      anonymized
    end

    # Generate data retention report
    #
    # @param records [Array<Hash>] Records to analyze
    # @return [Hash] Retention report
    def retention_report(records)
      total = records.count
      expired = records.count { |r| should_delete?(r[:created_at]) }
      active = total - expired

      {
        total_records: total,
        active_records: active,
        expired_records: expired,
        retention_period_days: @retention_days,
        next_expiry_date: next_expiry_date(records),
        compliance_status: expired.zero? ? "compliant" : "action_required"
      }
    end

    # Get next expiry date from a set of records
    #
    # @param records [Array<Hash>] Records to check
    # @return [Time, nil] Next expiry date or nil if none
    def next_expiry_date(records)
      active_records = records.reject { |r| should_delete?(r[:created_at]) }
      return nil if active_records.empty?

      oldest = active_records.min_by { |r| r[:created_at] }
      expiry_date(oldest[:created_at]) if oldest
    end

    # Validate retention policy meets regulatory requirements
    #
    # @param retention_days [Integer] Proposed retention period
    # @param jurisdiction [Symbol] Jurisdiction (:malaysia, :eu, :global)
    # @return [Hash] Validation result
    def self.validate_retention_policy(retention_days, jurisdiction: :malaysia)
      minimums = {
        malaysia: 2555,  # 7 years for financial records (Companies Act 2016)
        eu: 2555,        # Generally 6-7 years for financial records
        global: 2555     # Conservative approach
      }

      minimum = minimums[jurisdiction] || minimums[:global]

      if retention_days < minimum
        {
          valid: false,
          message: "Retention period (#{retention_days} days) is below minimum requirement " \
                   "(#{minimum} days) for #{jurisdiction} jurisdiction",
          minimum_required: minimum
        }
      else
        {
          valid: true,
          message: "Retention policy meets regulatory requirements",
          minimum_required: minimum
        }
      end
    end
  end
end
