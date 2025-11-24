# frozen_string_literal: true

module ToyyibPay
  # Utility methods for the ToyyibPay gem
  module Util
    module_function

    # Convert hash keys to strings recursively
    def stringify_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value.is_a?(Hash) ? stringify_keys(value) : value
      end
    end

    # Convert hash keys to symbols recursively
    def symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
      end
    end

    # Deep merge two hashes
    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, v1, v2|
        if v1.is_a?(Hash) && v2.is_a?(Hash)
          deep_merge(v1, v2)
        else
          v2
        end
      end
    end

    # Remove nil values from hash
    def compact_hash(hash)
      hash.reject { |_k, v| v.nil? }
    end

    # Convert object to query string
    def encode_parameters(params)
      return "" if params.nil? || params.empty?

      params.map do |key, value|
        if value.is_a?(Array)
          value.map { |v| "#{CGI.escape(key.to_s)}[]=#{CGI.escape(v.to_s)}" }.join("&")
        else
          "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
        end
      end.join("&")
    end

    # Log message with optional logger
    def log(logger, level, message)
      return unless logger

      logger.public_send(level, "[ToyyibPay] #{message}")
    end

    # Safe JSON parse
    def safe_parse_json(json_string)
      JSON.parse(json_string)
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON response: #{e.message}"
    end

    # Sanitize text input to prevent XSS attacks
    # This provides basic HTML entity encoding for user-provided text
    # that will be displayed in web interfaces
    #
    # @param text [String] Text to sanitize
    # @return [String] Sanitized text
    def sanitize_text(text)
      return text unless text.is_a?(String)

      text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&#39;")
    end

    # Redact sensitive information from parameters for logging
    #
    # @param params [Hash] Parameters to redact
    # @return [Hash] Parameters with sensitive values redacted
    def redact_sensitive_params(params)
      return params unless params.is_a?(Hash)

      sensitive_keys = %w[
        userSecretKey
        api_key
        secret
        password
        token
        billEmail
        billPhone
        billTo
        billpayorEmail
        billpayorPhone
      ]

      params.transform_values.with_index do |value, key|
        if sensitive_keys.any? { |sk| key.to_s.downcase.include?(sk.downcase) }
          "[REDACTED]"
        elsif value.is_a?(Hash)
          redact_sensitive_params(value)
        else
          value
        end
      end
    end

    # Validate and sanitize bill parameters
    # Prevents common injection attacks and ensures data integrity
    #
    # @param params [Hash] Bill parameters
    # @return [Hash] Sanitized parameters
    def sanitize_bill_params(params)
      sanitized = params.dup

      # Sanitize text fields that may contain user input
      text_fields = %i[billName billDescription billContentEmail]
      text_fields.each do |field|
        sanitized[field] = sanitize_text(sanitized[field]) if sanitized[field]
      end

      # Ensure billPriceSetting is a valid value
      if sanitized[:billPriceSetting]
        unless %w[0 1].include?(sanitized[:billPriceSetting].to_s)
          raise ArgumentError, "billPriceSetting must be '0' (fixed) or '1' (open)"
        end
      end

      # Ensure billPaymentChannel is a valid value
      if sanitized[:billPaymentChannel]
        unless %w[0 1 2].include?(sanitized[:billPaymentChannel].to_s)
          raise ArgumentError, "billPaymentChannel must be '0' (FPX), '1' (Credit Card), or '2' (Both)"
        end
      end

      # Ensure amount is numeric and positive if present
      if sanitized[:billAmount]
        amount = sanitized[:billAmount].to_s.to_i
        if amount <= 0
          raise ArgumentError, "billAmount must be a positive integer (in cents)"
        end
      end

      sanitized
    end
  end
end
