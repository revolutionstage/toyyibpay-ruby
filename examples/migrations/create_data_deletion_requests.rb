# frozen_string_literal: true

# Example migration for GDPR "Right to Erasure" tracking
# Track customer data deletion requests and their processing
#
# Generate in your Rails app:
#   rails generate model DataDeletionRequest user:references
#
# Then modify with the fields below.

class CreateDataDeletionRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :data_deletion_requests do |t|
      t.references :user, foreign_key: true, null: true # Null after user deletion

      # Request details
      t.string :request_type # "erasure", "anonymization", "portability"
      t.text :reason
      t.string :status, default: "pending" # pending, approved, processing, completed, denied

      # GDPR requires response within 1 month
      t.datetime :requested_at, null: false
      t.datetime :deadline_at, null: false # 1 month from requested_at
      t.datetime :completed_at

      # Processing details
      t.datetime :processed_at
      t.references :processed_by, foreign_key: { to_table: :users }
      t.text :processing_notes

      # Denial reason (if applicable)
      t.text :denial_reason

      # IP and user agent for audit trail
      t.string :ip_address
      t.string :user_agent

      # Data affected (JSON of what was deleted/anonymized)
      t.jsonb :affected_data, default: {}

      t.timestamps
    end

    add_index :data_deletion_requests, :status
    add_index :data_deletion_requests, :requested_at
    add_index :data_deletion_requests, :deadline_at
  end
end
