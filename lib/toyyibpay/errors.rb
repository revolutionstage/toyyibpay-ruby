# frozen_string_literal: true

module ToyyibPay
  # Base error class for all toyyibPay errors
  class Error < StandardError
    attr_reader :http_status, :http_body, :http_headers, :request_id

    def initialize(message = nil, http_status: nil, http_body: nil, http_headers: nil, request_id: nil)
      super(message)
      @http_status = http_status
      @http_body = http_body
      @http_headers = http_headers || {}
      @request_id = request_id
    end

    def to_s
      status_string = http_status.nil? ? "" : "(Status #{http_status}) "
      id_string = request_id.nil? ? "" : "(Request #{request_id}) "
      "#{status_string}#{id_string}#{message}"
    end
  end

  # Configuration errors
  class ConfigurationError < Error; end

  # API errors
  class APIError < Error; end

  # Authentication errors (401)
  class AuthenticationError < APIError; end

  # Invalid request errors (400)
  class InvalidRequestError < APIError; end

  # Rate limit errors (429)
  class RateLimitError < APIError; end

  # Connection errors
  class APIConnectionError < Error; end

  # Timeout errors
  class TimeoutError < APIConnectionError; end
end
