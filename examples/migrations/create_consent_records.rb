# frozen_string_literal: true

# Example migration for creating a consent tracking table
# Required for PDPA Section 6 and GDPR Article 7 compliance
#
# Generate in your Rails app:
#   rails generate model ConsentRecord user:references purpose:string
#
# Then modify with the fields below.

class CreateConsentRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :consent_records do |t|
      t.references :user, null: false, foreign_key: true

      # What the consent is for
      t.string :purpose, null: false # e.g., "payment_processing", "marketing"
      t.text :description # Full text shown to user

      # When and how consent was obtained
      t.datetime :obtained_at, null: false
      t.string :obtained_via # e.g., "checkout_page", "settings_page"
      t.string :ip_address
      t.string :user_agent

      # Privacy policy version (important for proving valid consent)
      t.string :version, null: false # e.g., "2024-01"

      # Consent expiry (GDPR requires re-consent after reasonable period)
      t.datetime :expires_at

      # Withdrawal
      t.datetime :withdrawn_at
      t.string :withdrawn_via

      t.timestamps
    end

    add_index :consent_records, [:user_id, :purpose]
    add_index :consent_records, :obtained_at
    add_index :consent_records, :expires_at
  end
end
