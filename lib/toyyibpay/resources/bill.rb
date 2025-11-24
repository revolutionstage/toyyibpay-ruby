# frozen_string_literal: true

module ToyyibPay
  module Resources
    # Bill resource for managing bills/invoices
    class Bill < APIResource
      # Create a new bill
      #
      # @param params [Hash] Bill parameters
      # @option params [String] :categoryCode Category code (optional if set in client)
      # @option params [String] :billName Bill name (required)
      # @option params [String] :billDescription Bill description (required)
      # @option params [String] :billPriceSetting Bill price setting: 0 = Fixed, 1 = Open (required)
      # @option params [String] :billPayorInfo Payor info: 0 = Required, 1 = Optional (required)
      # @option params [String] :billAmount Amount in cents (required if billPriceSetting = 0)
      # @option params [String] :billReturnUrl Return URL after payment
      # @option params [String] :billCallbackUrl Callback URL for payment notification
      # @option params [String] :billExternalReferenceNo External reference number
      # @option params [String] :billTo Recipient email
      # @option params [String] :billEmail Sender email
      # @option params [String] :billPhone Phone number
      # @option params [String] :billSplitPayment Split payment: 0 = No, 1 = Yes
      # @option params [String] :billSplitPaymentArgs Split payment details (JSON string)
      # @option params [String] :billPaymentChannel Payment channel: 0 = FPX, 1 = Credit Card, 2 = Both
      # @option params [String] :billContentEmail Email content
      # @option params [String] :billChargeToCustomer Charge to customer: 0 = No, 1 = Yes
      # @option params [String] :billExpiryDate Expiry date (YYYY-MM-DD)
      # @option params [String] :billExpiryDays Days until expiry
      #
      # @return [Array<Hash>] Created bill details including BillCode
      #
      # @example
      #   bill = client.bills.create(
      #     billName: "Invoice #001",
      #     billDescription: "Payment for services",
      #     billPriceSetting: "0",
      #     billPayorInfo: "1",
      #     billAmount: "10000",
      #     billReturnUrl: "https://example.com/return",
      #     billPaymentChannel: "0"
      #   )
      def create(params = {})
        validate_create_params!(params)

        # Sanitize and validate input parameters
        params = ToyyibPay::Util.sanitize_bill_params(params)

        # Ensure categoryCode is set
        params[:categoryCode] ||= client.config.category_code

        request(:post, "/index.php/api/createBill", params)
      end

      # Get bill transactions
      #
      # @param bill_code [String] Bill code
      #
      # @return [Array<Hash>] List of transactions
      #
      # @example
      #   transactions = client.bills.transactions("abc123xyz")
      def transactions(bill_code)
        raise ArgumentError, "bill_code is required" if bill_code.nil? || bill_code.empty?

        request(:post, "/index.php/api/getBillTransactions", billCode: bill_code)
      end

      # Run a bill (trigger bill creation for recurring bills)
      #
      # @param params [Hash] Run bill parameters
      # @option params [String] :billCode Bill code (required)
      # @option params [String] :billpayorEmail Payor email (required)
      # @option params [String] :billpayorName Payor name (required)
      # @option params [String] :billpayorPhone Payor phone (required)
      # @option params [String] :billBankID Bank ID for FPX (optional)
      #
      # @return [Hash] Run bill response
      #
      # @example
      #   result = client.bills.run(
      #     billCode: "abc123",
      #     billpayorEmail: "customer@example.com",
      #     billpayorName: "John Doe",
      #     billpayorPhone: "0123456789"
      #   )
      def run(params = {})
        validate_run_params!(params)
        request(:post, "/index.php/api/runBill", params)
      end

      # Generate payment URL for a bill
      #
      # @param bill_code [String] Bill code
      #
      # @return [String] Payment URL
      #
      # @example
      #   url = client.bills.payment_url("abc123xyz")
      def payment_url(bill_code)
        raise ArgumentError, "bill_code is required" if bill_code.nil? || bill_code.empty?

        base = client.config.effective_api_base
        "#{base}/#{bill_code}"
      end

      # Alias for convenience
      alias get_transactions transactions

      private

      def validate_create_params!(params)
        raise ArgumentError, "billName is required" unless params[:billName]
        raise ArgumentError, "billDescription is required" unless params[:billDescription]
        raise ArgumentError, "billPriceSetting is required" unless params[:billPriceSetting]
        raise ArgumentError, "billPayorInfo is required" unless params[:billPayorInfo]

        # If price is fixed, amount is required
        if params[:billPriceSetting] == "0" && !params[:billAmount]
          raise ArgumentError, "billAmount is required when billPriceSetting is 0 (fixed)"
        end
      end

      def validate_run_params!(params)
        raise ArgumentError, "billCode is required" unless params[:billCode]
        raise ArgumentError, "billpayorEmail is required" unless params[:billpayorEmail]
        raise ArgumentError, "billpayorName is required" unless params[:billpayorName]
        raise ArgumentError, "billpayorPhone is required" unless params[:billpayorPhone]
      end
    end
  end
end
