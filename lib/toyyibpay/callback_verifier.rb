# frozen_string_literal: true

module ToyyibPay
  # Verifies payment callbacks from ToyyibPay
  #
  # SECURITY WARNING: Never trust callback data directly!
  # ToyyibPay does not provide HMAC signatures for callbacks.
  # Always verify payment status by querying the API.
  #
  # @example Verify a callback
  #   verifier = ToyyibPay::CallbackVerifier.new
  #   result = verifier.verify(
  #     bill_code: params[:billcode],
  #     expected_amount: order.total_cents,
  #     expected_status: "1"
  #   )
  #
  #   if result.verified?
  #     order.mark_as_paid!
  #   end
  class CallbackVerifier
    # Verification result object
    class Result
      attr_reader :verified, :transaction, :errors

      def initialize(verified:, transaction: nil, errors: [])
        @verified = verified
        @transaction = transaction
        @errors = errors
      end

      def verified?
        @verified
      end

      def failed?
        !@verified
      end

      def amount
        @transaction&.dig("billpaymentAmount")
      end

      def status
        @transaction&.dig("billpaymentStatus")
      end

      def reference_no
        @transaction&.dig("billPaymentInvoiceNo")
      end

      def paid_at
        @transaction&.dig("billPaymentDate")
      end
    end

    attr_reader :client

    # @param client [ToyyibPay::Client] Optional client instance
    def initialize(client = nil)
      @client = client || ToyyibPay.default_client
    end

    # Verify a payment callback by querying the ToyyibPay API
    #
    # This implements the "Double-Check" pattern to prevent callback spoofing.
    # The callback is treated as an untrusted "wake-up" signal, and we verify
    # the actual payment status by querying the authoritative API.
    #
    # @param bill_code [String] Bill code from callback
    # @param expected_amount [String, Integer] Expected payment amount in cents
    # @param expected_status [String] Expected status ID ("1" = success)
    # @param verify_amount [Boolean] Whether to verify the amount matches (default: true)
    #
    # @return [Result] Verification result
    #
    # @example Basic verification
    #   result = verifier.verify(
    #     bill_code: "h5bz62x1",
    #     expected_amount: "10000",
    #     expected_status: "1"
    #   )
    #
    #   if result.verified?
    #     puts "Payment verified: #{result.amount}"
    #     order.mark_as_paid!
    #   else
    #     puts "Verification failed: #{result.errors.join(', ')}"
    #   end
    #
    # @example Verify without amount check (for open-price bills)
    #   result = verifier.verify(
    #     bill_code: "h5bz62x1",
    #     expected_status: "1",
    #     verify_amount: false
    #   )
    def verify(bill_code:, expected_amount: nil, expected_status: "1", verify_amount: true)
      errors = []

      # Validate inputs
      if bill_code.nil? || bill_code.empty?
        errors << "bill_code is required"
        return Result.new(verified: false, errors: errors)
      end

      if verify_amount && (expected_amount.nil? || expected_amount.to_s.empty?)
        errors << "expected_amount is required when verify_amount is true"
        return Result.new(verified: false, errors: errors)
      end

      # Query the authoritative API
      begin
        transactions = client.bills.transactions(bill_code)
      rescue ToyyibPay::Error => e
        errors << "API verification failed: #{e.message}"
        return Result.new(verified: false, errors: errors)
      end

      # Check if we have any transactions
      if transactions.nil? || transactions.empty?
        errors << "No transactions found for bill code"
        return Result.new(verified: false, errors: errors)
      end

      # Get the most recent transaction
      transaction = transactions.first

      # Verify the status
      actual_status = transaction["billpaymentStatus"]
      if actual_status != expected_status
        errors << "Status mismatch: expected '#{expected_status}', got '#{actual_status}'"
        return Result.new(verified: false, transaction: transaction, errors: errors)
      end

      # Verify the amount if required
      if verify_amount
        actual_amount = transaction["billpaymentAmount"].to_s
        expected_amount_str = expected_amount.to_s

        # Normalize amounts (remove decimals, convert to cents if needed)
        actual_cents = normalize_amount(actual_amount)
        expected_cents = normalize_amount(expected_amount_str)

        if actual_cents != expected_cents
          errors << "Amount mismatch: expected '#{expected_cents}' cents, got '#{actual_cents}' cents"
          return Result.new(verified: false, transaction: transaction, errors: errors)
        end
      end

      # Verification successful
      Result.new(verified: true, transaction: transaction)
    end

    # Verify callback and raise an error if verification fails
    #
    # @param (see #verify)
    # @return [Result] Verification result (only if successful)
    # @raise [ToyyibPay::InvalidRequestError] If verification fails
    def verify!(bill_code:, expected_amount: nil, expected_status: "1", verify_amount: true)
      result = verify(
        bill_code: bill_code,
        expected_amount: expected_amount,
        expected_status: expected_status,
        verify_amount: verify_amount
      )

      unless result.verified?
        raise ToyyibPay::InvalidRequestError, "Callback verification failed: #{result.errors.join(', ')}"
      end

      result
    end

    private

    # Normalize amount to cents (integer)
    def normalize_amount(amount)
      amount_str = amount.to_s.strip

      # If amount contains decimal point, convert to cents
      if amount_str.include?(".")
        (amount_str.to_f * 100).round
      else
        amount_str.to_i
      end
    end
  end
end
