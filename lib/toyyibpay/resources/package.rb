# frozen_string_literal: true

module ToyyibPay
  module Resources
    # Package resource for managing package operations
    class Package < APIResource
      # Get all available packages
      #
      # @return [Array<Hash>] List of packages
      #
      # @example
      #   packages = client.packages.all
      def all
        response = request(:post, "/index.php/api/getPackage")
        response.is_a?(Array) ? response : []
      end

      # Alias for convenience
      alias list all
    end
  end
end
