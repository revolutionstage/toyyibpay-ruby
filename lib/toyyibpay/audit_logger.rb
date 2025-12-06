# frozen_string_literal: true

module ToyyibPay
  # Audit logger for PCI-DSS Requirement 10 compliance
  #
  # Provides structured logging of payment-related events for security auditing,
  # fraud detection, and regulatory compliance.
  #
  # @example Basic usage
  #   ToyyibPay::AuditLogger.log(:bill_created,
  #     user_id: current_user.id,
  #     order_id: order.id,
  #     amount: "10000",
  #     ip_address: request.remote_ip
  #   )
  #
  # @example Configure custom logger
  #   ToyyibPay::AuditLogger.configure do |config|
  #     config.logger = Logger.new(Rails.root.join("log", "toyyibpay_audit.log"))
  #     config.enabled = Rails.env.production?
  #   end
  class AuditLogger
    class Configuration
      attr_accessor :logger, :enabled, :log_level

      def initialize
        @logger = nil
        @enabled = true
        @log_level = :info
      end
    end

    class << self
      # Get current configuration
      #
      # @return [Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # Configure audit logger
      #
      # @yield [configuration] Configuration object
      def configure
        yield(configuration) if block_given?
      end

      # Reset configuration to defaults
      def reset!
        @configuration = Configuration.new
      end

      # Log an audit event
      #
      # @param event_type [Symbol] Type of event
      # @param data [Hash] Event data
      #
      # @example
      #   AuditLogger.log(:payment_verified,
      #     user_id: 123,
      #     order_id: 456,
      #     bill_code: "abc123",
      #     amount: "10000",
      #     status: "success",
      #     ip_address: "192.168.1.1"
      #   )
      def log(event_type, data = {})
        return unless configuration.enabled
        return unless configuration.logger

        entry = build_entry(event_type, data)
        configuration.logger.public_send(configuration.log_level, format_entry(entry))
      end

      # Log bill creation event
      #
      # @param data [Hash] Bill creation data
      def log_bill_created(data)
        log(:bill_created, data.merge(action: "create_bill"))
      end

      # Log payment verification event
      #
      # @param data [Hash] Verification data
      def log_payment_verified(data)
        log(:payment_verified, data.merge(action: "verify_payment"))
      end

      # Log payment verification failure (potential fraud)
      #
      # @param data [Hash] Failure data
      def log_verification_failed(data)
        log(:verification_failed, data.merge(action: "verify_payment", severity: "high"))
      end

      # Log callback received event
      #
      # @param data [Hash] Callback data
      def log_callback_received(data)
        log(:callback_received, data.merge(action: "receive_callback"))
      end

      # Log data access event (PDPA/GDPR compliance)
      #
      # @param data [Hash] Access data
      def log_data_access(data)
        log(:data_access, data.merge(action: "access_customer_data"))
      end

      # Log data deletion event (right to erasure)
      #
      # @param data [Hash] Deletion data
      def log_data_deletion(data)
        log(:data_deletion, data.merge(action: "delete_customer_data"))
      end

      # Log consent event
      #
      # @param data [Hash] Consent data
      def log_consent(data)
        log(:consent_obtained, data.merge(action: "obtain_consent"))
      end

      private

      def build_entry(event_type, data)
        {
          timestamp: Time.now.utc.iso8601,
          event_type: event_type.to_s,
          user_id: data[:user_id],
          order_id: data[:order_id],
          bill_code: data[:bill_code],
          amount: data[:amount],
          status: data[:status],
          ip_address: data[:ip_address],
          session_id: data[:session_id],
          action: data[:action],
          severity: data[:severity] || "info",
          errors: data[:errors],
          metadata: sanitize_metadata(data[:metadata] || {})
        }.compact
      end

      def sanitize_metadata(metadata)
        return metadata unless metadata.is_a?(Hash)

        # Remove PII from metadata
        ToyyibPay::Compliance.redact_pii(metadata)
      end

      def format_entry(entry)
        "[ToyyibPay Audit] #{entry.to_json}"
      end
    end
  end
end
