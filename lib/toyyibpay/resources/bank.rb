# frozen_string_literal: true

module ToyyibPay
  module Resources
    # Bank resource for managing bank operations
    class Bank < APIResource
      # Get all available banks
      #
      # @return [Array<Hash>] List of banks
      #
      # @example
      #   banks = client.banks.all
      def all
        response = request(:post, "/index.php/api/getBank")
        response.is_a?(Array) ? response : []
      end

      # Get FPX banks
      #
      # @return [Array<Hash>] List of FPX banks
      #
      # @example
      #   fpx_banks = client.banks.fpx
      def fpx
        response = request(:post, "/index.php/api/getBankFPX")
        response.is_a?(Array) ? response : []
      end

      # Alias for convenience
      alias list all
      alias all_fpx fpx
    end
  end
end
