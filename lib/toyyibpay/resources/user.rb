# frozen_string_literal: true

module ToyyibPay
  module Resources
    # User resource for managing user information
    class User < APIResource
      # Get user status
      #
      # @return [Hash] User status information
      #
      # @example
      #   status = client.users.status
      def status
        request(:post, "/index.php/api/getUserStatus")
      end

      # Alias for convenience
      alias get_status status
    end
  end
end
