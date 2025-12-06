# frozen_string_literal: true

module ToyyibPay
  module Resources
    # Category resource for managing bill categories
    class Category < APIResource
      # Create a new category
      #
      # @param params [Hash] Category parameters
      # @option params [String] :catname Category name (required)
      # @option params [String] :catdescription Category description (required)
      #
      # @return [Hash] Created category details including categoryCode
      #
      # @example
      #   category = client.categories.create(
      #     catname: "My Products",
      #     catdescription: "Product sales category"
      #   )
      def create(params = {})
        validate_create_params!(params)
        request(:post, "/index.php/api/createCategory", params)
      end

      # Get category details
      #
      # @param category_code [String] Category code (optional if set in client)
      #
      # @return [Hash] Category details
      #
      # @example
      #   details = client.categories.retrieve("abc123")
      def retrieve(category_code = nil)
        code = category_code || client.config.category_code
        raise ArgumentError, "category_code is required" if code.nil? || code.empty?

        request(:post, "/index.php/api/getCategoryDetails", categoryCode: code)
      end

      # Alias for convenience
      alias get retrieve
      alias find retrieve

      private

      def validate_create_params!(params)
        raise ArgumentError, "catname is required" unless params[:catname]
        raise ArgumentError, "catdescription is required" unless params[:catdescription]
      end
    end
  end
end
