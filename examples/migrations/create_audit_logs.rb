# frozen_string_literal: true

# Example migration for creating audit logs table
# Required for PCI-DSS Requirement 10 compliance
#
# Generate in your Rails app:
#   rails generate model AuditLog
#
# Then modify with the fields below.

class CreateAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_logs do |t|
      # Who performed the action
      t.references :user, foreign_key: true, null: true # Null for system actions
      t.string :session_id

      # What action was performed
      t.string :event_type, null: false # e.g., "payment_verified", "data_accessed"
      t.string :action # e.g., "verify_payment", "view_transaction"
      t.string :severity, default: "info" # info, warning, error, critical

      # What was affected
      t.string :resource_type # e.g., "Payment", "Order"
      t.bigint :resource_id
      t.string :bill_code

      # Transaction details
      t.decimal :amount, precision: 10, scale: 2
      t.string :status

      # Where it happened
      t.string :ip_address
      t.string :user_agent

      # Additional context (stored as JSON)
      t.jsonb :metadata, default: {}

      # Errors (if any)
      t.text :errors

      # When it happened
      t.datetime :timestamp, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    # Indexes for compliance queries
    add_index :audit_logs, :event_type
    add_index :audit_logs, :timestamp
    add_index :audit_logs, :user_id
    add_index :audit_logs, :bill_code
    add_index :audit_logs, :ip_address
    add_index :audit_logs, [:resource_type, :resource_id]

    # Metadata search (PostgreSQL only)
    add_index :audit_logs, :metadata, using: :gin
  end
end
