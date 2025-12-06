# frozen_string_literal: true

require "faraday"
require "json"
require "cgi"

module ToyyibPay
  # Handles HTTP requests to the toyyibPay API
  class APIRequestor
    attr_reader :config

    def initialize(config)
      @config = config
    end

    # Execute an API request
    def request(method, path, params = {})
      config.validate!

      url = build_url(path)
      headers = build_headers
      body = build_body(params)

      Util.log(config.logger, :info, "#{method.upcase} #{url}")
      # Redact sensitive information from logs
      safe_params = Util.redact_sensitive_params(params)
      Util.log(config.logger, :debug, "Request params: #{safe_params.inspect}")

      response = execute_request_with_retry(method, url, headers, body)
      handle_response(response)
    rescue Faraday::TimeoutError => e
      raise TimeoutError, "Request timeout: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      raise APIConnectionError, "Connection failed: #{e.message}"
    rescue Faraday::Error => e
      raise APIConnectionError, "Network error: #{e.message}"
    end

    private

    def build_url(path)
      base = config.effective_api_base
      # toyyibPay API paths are like /index.php/api/createBill
      "#{base}#{path}"
    end

    def build_headers
      {
        "Content-Type" => "application/x-www-form-urlencoded",
        "User-Agent" => "ToyyibPay Ruby Gem/#{ToyyibPay::VERSION}",
        "Accept" => "application/json"
      }
    end

    def build_body(params)
      # Always include userSecretKey
      body_params = { userSecretKey: config.api_key }

      # Add category code if available and not already in params
      body_params[:categoryCode] = config.category_code if config.category_code && !params[:categoryCode]

      # Merge with provided params
      body_params.merge!(params)

      # Remove nil values
      body_params = Util.compact_hash(body_params)

      Util.encode_parameters(body_params)
    end

    def execute_request_with_retry(method, url, headers, body)
      retries = 0
      max_retries = config.max_retries

      begin
        execute_request(method, url, headers, body)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        retries += 1
        if retries <= max_retries
          sleep_time = retry_sleep_time(retries)
          Util.log(config.logger, :warn, "Request failed, retrying in #{sleep_time}s (#{retries}/#{max_retries})")
          sleep(sleep_time)
          retry
        end
        raise
      end
    end

    def execute_request(method, url, headers, body)
      connection = build_connection
      connection.public_send(method) do |req|
        req.url(url)
        req.headers.update(headers)
        req.body = body if body && !body.empty?
      end
    end

    def build_connection
      Faraday.new do |conn|
        conn.options.timeout = config.read_timeout
        conn.options.open_timeout = config.open_timeout
        conn.adapter Faraday.default_adapter
      end
    end

    def retry_sleep_time(retry_count)
      # Exponential backoff: 1s, 2s, 4s
      [1 * (2**(retry_count - 1)), 10].min
    end

    def handle_response(response)
      Util.log(config.logger, :info, "Response status: #{response.status}")
      Util.log(config.logger, :debug, "Response body: #{response.body}")

      case response.status
      when 200..299
        parse_success_response(response)
      when 400
        raise InvalidRequestError.new(
          "Invalid request parameters",
          http_status: response.status,
          http_body: response.body,
          http_headers: response.headers
        )
      when 401
        raise AuthenticationError.new(
          "Authentication failed - check your API key",
          http_status: response.status,
          http_body: response.body,
          http_headers: response.headers
        )
      when 429
        raise RateLimitError.new(
          "Rate limit exceeded",
          http_status: response.status,
          http_body: response.body,
          http_headers: response.headers
        )
      else
        raise APIError.new(
          "API error (status #{response.status})",
          http_status: response.status,
          http_body: response.body,
          http_headers: response.headers
        )
      end
    end

    def parse_success_response(response)
      return nil if response.body.nil? || response.body.empty?

      # toyyibPay returns JSON arrays for some endpoints
      parsed = Util.safe_parse_json(response.body)

      # Check for error in response body
      if parsed.is_a?(Array) && parsed.first.is_a?(Hash) && parsed.first["error"]
        raise APIError, parsed.first["error"]
      elsif parsed.is_a?(Hash) && parsed["error"]
        raise APIError, parsed["error"]
      end

      parsed
    end
  end
end
