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
  end
end
