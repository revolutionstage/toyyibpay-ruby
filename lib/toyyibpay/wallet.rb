# frozen_string_literal: true

require_relative "wallet/apple_wallet"
require_relative "wallet/google_wallet"

module ToyyibPay
  # Wallet module for native OS ticketing and digital wallet integration
  # Supports Apple Wallet (Passbook) and Google Wallet
  #
  # @example Generate Apple Wallet pass
  #   apple = ToyyibPay::Wallet.apple(
  #     pass_type_identifier: "pass.com.example.event",
  #     team_identifier: "ABCD1234",
  #     certificate_path: "/path/to/pass.p12"
  #   )
  #   apple.generate_pkpass(transaction, "/tmp/ticket", event_name: "Concert")
  #
  # @example Generate Google Wallet pass
  #   google = ToyyibPay::Wallet.google(
  #     issuer_id: "3388000000012345678",
  #     service_account_key_path: "/path/to/service-account.json"
  #   )
  #   url = google.save_url(transaction, event_name: "Concert")
  module Wallet
    class << self
      # Create an Apple Wallet pass generator
      #
      # @param options [Hash] Apple Wallet configuration options
      # @return [AppleWallet] Apple Wallet generator instance
      #
      # @see AppleWallet#initialize for available options
      def apple(options = {})
        AppleWallet.new(options)
      end

      # Create a Google Wallet pass generator
      #
      # @param options [Hash] Google Wallet configuration options
      # @return [GoogleWallet] Google Wallet generator instance
      #
      # @see GoogleWallet#initialize for available options
      def google(options = {})
        GoogleWallet.new(options)
      end

      # Generate wallet passes for multiple platforms at once
      #
      # @param transaction [Hash] Transaction data from ToyyibPay
      # @param options [Hash] Shared options for all platforms
      # @param platforms [Hash] Platform-specific options
      # @option platforms [Hash] :apple Apple Wallet configuration
      # @option platforms [Hash] :google Google Wallet configuration
      #
      # @return [Hash] Generated pass data for each platform
      #
      # @example
      #   passes = ToyyibPay::Wallet.generate_all(
      #     transaction,
      #     { event_name: "Concert", event_date: "2024-03-15" },
      #     {
      #       apple: { certificate_path: "/path/to/cert.p12" },
      #       google: { issuer_id: "12345" }
      #     }
      #   )
      def generate_all(transaction, options = {}, platforms = {})
        result = {}

        if platforms[:apple]
          apple_wallet = apple(platforms[:apple])
          result[:apple] = {
            pass_data: apple_wallet.generate_pass(transaction, options),
            can_sign: apple_wallet.can_sign?
          }
        end

        if platforms[:google]
          google_wallet = google(platforms[:google])
          result[:google] = {
            pass_data: google_wallet.to_hash(transaction, options),
            save_url: google_wallet.configured? ? google_wallet.save_url(transaction, options) : nil
          }
        end

        result
      end

      # Generate HTML with buttons for all configured wallets
      #
      # @param transaction [Hash] Transaction data
      # @param options [Hash] Shared ticket options
      # @param platforms [Hash] Platform-specific configuration
      #
      # @return [String] HTML containing wallet buttons
      #
      # @example
      #   html = ToyyibPay::Wallet.buttons_html(transaction, options, platforms)
      def buttons_html(transaction, options = {}, platforms = {})
        buttons = []

        # Apple Wallet button (link to download .pkpass)
        if platforms[:apple] && platforms[:apple][:download_url]
          buttons << apple_button_html(platforms[:apple][:download_url])
        end

        # Google Wallet button
        if platforms[:google]
          google_wallet = google(platforms[:google])
          if google_wallet.configured?
            buttons << google_wallet.add_button_html(transaction, options)
          end
        end

        return "" if buttons.empty?

        <<~HTML
          <div class="wallet-buttons" style="display: flex; gap: 12px; flex-wrap: wrap; justify-content: center; padding: 20px;">
            #{buttons.join("\n")}
          </div>
        HTML
      end

      private

      def apple_button_html(download_url)
        <<~HTML
          <a href="#{download_url}" style="display: inline-block;">
            <img src="https://developer.apple.com/wallet/add-to-apple-wallet-guidelines/images/add-to-apple-wallet-logo.svg"
                 alt="Add to Apple Wallet"
                 style="height: 48px; cursor: pointer;">
          </a>
        HTML
      end
    end
  end
end
