# frozen_string_literal: true

# Example migration for adding compliance fields to your payments table
# This supports PCI-DSS audit logging and PDPA/GDPR data protection requirements
#
# Generate in your Rails app:
#   rails generate migration AddComplianceFieldsToPayments
#
# Then copy the relevant sections below.

class AddComplianceFieldsToPayments < ActiveRecord::Migration[7.0]
  def change
    # ToyyibPay integration fields
    add_column :payments, :toyyibpay_bill_code, :string
    add_column :payments, :toyyibpay_reference_no, :string
    add_column :payments, :toyyibpay_status, :string

    # Audit trail (PCI-DSS Requirement 10)
    add_column :payments, :payment_initiated_at, :datetime
    add_column :payments, :payment_initiated_ip, :string
    add_column :payments, :payment_completed_at, :datetime
    add_column :payments, :payment_verified_at, :datetime
    add_column :payments, :payment_verification_result, :text # JSON

    # Consent tracking (PDPA/GDPR)
    add_column :payments, :consent_obtained_at, :datetime
    add_column :payments, :consent_ip_address, :string
    add_column :payments, :consent_user_agent, :string
    add_column :payments, :consent_version, :string # Version your privacy policy

    # Data retention
    add_column :payments, :data_anonymized_at, :datetime

    # Indexes for performance and compliance queries
    add_index :payments, :toyyibpay_bill_code, unique: true
    add_index :payments, :toyyibpay_reference_no, unique: true
    add_index :payments, :payment_initiated_at
    add_index :payments, :consent_obtained_at
    add_index :payments, :data_anonymized_at

    # Prevent duplicate payment processing (PCI-DSS)
    add_index :payments, [:order_id, :toyyibpay_reference_no], unique: true, name: "index_payments_on_order_and_reference"
  end
end
