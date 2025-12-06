# frozen_string_literal: true

module ToyyibPay
  module Resources
    # Settlement resource for managing settlements
    class Settlement < APIResource
      # Get settlement summary
      #
      # @param params [Hash] Settlement parameters
      # @option params [String] :settlementDate Settlement date (YYYY-MM-DD)
      #
      # @return [Hash] Settlement summary
      #
      # @example
      #   summary = client.settlements.summary(settlementDate: "2025-01-15")
      def summary(params = {})
        request(:post, "/index.php/api/getSettlementSummary", params)
      end

      # Alias for convenience
      alias get_summary summary
    end
  end
end
