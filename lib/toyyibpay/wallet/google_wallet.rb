# frozen_string_literal: true

require "json"
require "digest"
require "base64"
require "time"

module ToyyibPay
  module Wallet
    # Google Wallet integration for generating event tickets and passes
    # Uses Google Wallet API with JWT (JSON Web Token) for pass generation
    #
    # Requirements:
    # - Google Cloud project with Wallet API enabled
    # - Service account with appropriate permissions
    # - Issuer ID from Google Pay & Wallet Console
    #
    # @see https://developers.google.com/wallet/tickets/events
    class GoogleWallet
      # Google Wallet API base URL
      API_BASE_URL = "https://walletobjects.googleapis.com/walletobjects/v1"

      # Save to Google Wallet URL
      SAVE_URL = "https://pay.google.com/gp/v/save"

      attr_reader :options

      # Initialize Google Wallet generator
      #
      # @param options [Hash] Configuration options
      # @option options [String] :issuer_id Google Wallet Issuer ID (required)
      # @option options [String] :service_account_email Service account email
      # @option options [String] :service_account_key_path Path to service account JSON key
      # @option options [Hash] :service_account_key Service account key data (alternative to path)
      # @option options [String] :class_id Default class ID for tickets
      #
      # @example
      #   wallet = ToyyibPay::Wallet::GoogleWallet.new(
      #     issuer_id: "3388000000012345678",
      #     service_account_email: "wallet@project.iam.gserviceaccount.com",
      #     service_account_key_path: "/path/to/service-account.json"
      #   )
      def initialize(options = {})
        @options = options
        @service_account_key = load_service_account_key
      end

      # Generate event ticket object data
      #
      # @param transaction [Hash] Transaction data from ToyyibPay
      # @param ticket_options [Hash] Ticket customization options
      # @option ticket_options [String] :event_name Event name
      # @option ticket_options [String] :event_date Event start date (ISO 8601)
      # @option ticket_options [String] :event_end_date Event end date (ISO 8601)
      # @option ticket_options [String] :venue_name Venue name
      # @option ticket_options [String] :venue_address Full venue address
      # @option ticket_options [Float] :latitude Venue latitude
      # @option ticket_options [Float] :longitude Venue longitude
      # @option ticket_options [String] :ticket_type Ticket type (e.g., "VIP", "General")
      # @option ticket_options [String] :seat_section Section
      # @option ticket_options [String] :seat_row Row
      # @option ticket_options [String] :seat_number Seat number
      # @option ticket_options [String] :gate Gate info
      # @option ticket_options [String] :logo_uri URL to logo image
      # @option ticket_options [String] :hero_image_uri URL to hero/banner image
      # @option ticket_options [String] :hex_background_color Background color (hex)
      # @option ticket_options [Hash] :custom_info Additional info to display
      #
      # @return [Hash] Event ticket object structure
      #
      # @example
      #   ticket = wallet.generate_ticket(transaction, {
      #     event_name: "Tech Conference 2024",
      #     event_date: "2024-03-15T09:00:00+08:00",
      #     venue_name: "KLCC Convention Center",
      #     venue_address: "Kuala Lumpur City Centre, Malaysia"
      #   })
      def generate_ticket(transaction, ticket_options = {})
        bill_code = extract_bill_code(transaction)
        object_id = generate_object_id(bill_code)

        {
          "id" => object_id,
          "classId" => ticket_options[:class_id] || default_class_id,
          "state" => "ACTIVE",
          "ticketHolderName" => transaction["billTo"] || transaction["billpayorName"] || "Guest",
          "ticketNumber" => generate_ticket_number(bill_code),
          "barcode" => {
            "type" => "QR_CODE",
            "value" => bill_code,
            "alternateText" => bill_code
          },
          "validTimeInterval" => build_time_interval(ticket_options),
          "eventName" => build_localized_string(ticket_options[:event_name] || transaction["billName"] || "Entry Pass"),
          "venue" => build_venue(ticket_options),
          "seatInfo" => build_seat_info(ticket_options),
          "ticketType" => build_localized_string(ticket_options[:ticket_type] || "General Admission"),
          "faceValue" => build_face_value(transaction),
          "groupingInfo" => {
            "sortIndex" => 1,
            "groupingId" => bill_code
          },
          "hexBackgroundColor" => ticket_options[:hex_background_color] || "#4a4a4a",
          "logo" => build_image(ticket_options[:logo_uri], "Logo"),
          "heroImage" => ticket_options[:hero_image_uri] ? build_image(ticket_options[:hero_image_uri], "Event") : nil,
          "linksModuleData" => build_links(ticket_options),
          "textModulesData" => build_text_modules(transaction, ticket_options),
          "infoModuleData" => build_info_module(transaction, ticket_options)
        }.compact
      end

      # Generate an event ticket class (template)
      #
      # @param class_options [Hash] Class configuration
      # @option class_options [String] :class_id Unique class ID
      # @option class_options [String] :event_name Event name
      # @option class_options [String] :issuer_name Issuer/organizer name
      # @option class_options [String] :review_status Review status (DRAFT, UNDER_REVIEW, APPROVED)
      # @option class_options [Boolean] :multiple_devices_and_holders_allowed Allow sharing
      #
      # @return [Hash] Event ticket class structure
      def generate_class(class_options = {})
        class_id = class_options[:class_id] || default_class_id

        {
          "id" => class_id,
          "issuerName" => class_options[:issuer_name] || options[:organization_name] || "ToyyibPay",
          "eventName" => build_localized_string(class_options[:event_name] || "Event"),
          "reviewStatus" => class_options[:review_status] || "DRAFT",
          "multipleDevicesAndHoldersAllowedStatus" => class_options[:multiple_devices_allowed] ? "MULTIPLE_HOLDERS" : "ONE_USER_ONE_DEVICE",
          "callbackOptions" => class_options[:callback_url] ? {
            "url" => class_options[:callback_url],
            "updateRequestUrl" => class_options[:update_callback_url] || class_options[:callback_url]
          } : nil,
          "classTemplateInfo" => {
            "cardTemplateOverride" => {
              "cardRowTemplateInfos" => [
                {
                  "twoItems" => {
                    "startItem" => {
                      "firstValue" => {
                        "fields" => [{ "fieldPath" => "object.textModulesData['date']" }]
                      }
                    },
                    "endItem" => {
                      "firstValue" => {
                        "fields" => [{ "fieldPath" => "object.textModulesData['time']" }]
                      }
                    }
                  }
                }
              ]
            }
          }
        }.compact
      end

      # Generate JWT for "Save to Google Wallet" link
      #
      # @param transaction [Hash] Transaction data
      # @param ticket_options [Hash] Ticket options
      #
      # @return [String] JWT token
      def generate_jwt(transaction, ticket_options = {})
        raise ConfigurationError, "Service account key required for JWT generation" unless @service_account_key

        ticket_object = generate_ticket(transaction, ticket_options)
        ticket_class = generate_class(ticket_options)

        payload = {
          "iss" => @service_account_key["client_email"],
          "aud" => "google",
          "typ" => "savetowallet",
          "iat" => Time.now.to_i,
          "origins" => ticket_options[:origins] || [],
          "payload" => {
            "eventTicketClasses" => [ticket_class],
            "eventTicketObjects" => [ticket_object]
          }
        }

        sign_jwt(payload)
      end

      # Generate "Save to Google Wallet" URL
      #
      # @param transaction [Hash] Transaction data
      # @param ticket_options [Hash] Ticket options
      #
      # @return [String] Save to Wallet URL
      #
      # @example
      #   url = wallet.save_url(transaction, event_name: "Concert")
      #   # => "https://pay.google.com/gp/v/save/eyJ..."
      def save_url(transaction, ticket_options = {})
        jwt = generate_jwt(transaction, ticket_options)
        "#{SAVE_URL}/#{jwt}"
      end

      # Generate pass data as JSON (for testing without signing)
      #
      # @param transaction [Hash] Transaction data
      # @param ticket_options [Hash] Ticket options
      #
      # @return [Hash] Complete pass data
      def to_hash(transaction, ticket_options = {})
        {
          class: generate_class(ticket_options),
          object: generate_ticket(transaction, ticket_options)
        }
      end

      # Generate HTML button for "Add to Google Wallet"
      #
      # @param transaction [Hash] Transaction data
      # @param ticket_options [Hash] Ticket options
      # @param button_options [Hash] Button styling options
      #
      # @return [String] HTML for Google Wallet button
      def add_button_html(transaction, ticket_options = {}, button_options = {})
        url = save_url(transaction, ticket_options)
        locale = button_options[:locale] || "en"
        width = button_options[:width] || 264
        height = button_options[:height] || 48

        <<~HTML
          <a href="#{url}" target="_blank" rel="noopener noreferrer">
            <img src="https://pay.google.com/about/static_kcs/images/#{locale}/add_to_google_wallet_button.svg"
                 alt="Add to Google Wallet"
                 width="#{width}"
                 height="#{height}"
                 style="cursor: pointer;">
          </a>
        HTML
      end

      # Check if the wallet is properly configured for API calls
      #
      # @return [Boolean]
      def configured?
        !!(options[:issuer_id] && @service_account_key)
      end

      private

      def load_service_account_key
        if options[:service_account_key]
          options[:service_account_key]
        elsif options[:service_account_key_path] && File.exist?(options[:service_account_key_path])
          JSON.parse(File.read(options[:service_account_key_path]))
        end
      end

      def extract_bill_code(transaction)
        transaction["BillCode"] || transaction["billCode"] || transaction["bill_code"] || "UNKNOWN"
      end

      def default_class_id
        options[:class_id] || "#{options[:issuer_id]}.event_ticket_class"
      end

      def generate_object_id(bill_code)
        "#{options[:issuer_id]}.#{Digest::SHA256.hexdigest(bill_code)[0..11]}"
      end

      def generate_ticket_number(bill_code)
        "TKT-#{Digest::SHA256.hexdigest(bill_code)[0..7].upcase}"
      end

      def build_localized_string(text, language = "en")
        return nil unless text

        {
          "defaultValue" => {
            "language" => language,
            "value" => text
          }
        }
      end

      def build_time_interval(ticket_options)
        return nil unless ticket_options[:event_date]

        interval = {
          "start" => {
            "date" => ticket_options[:event_date]
          }
        }

        if ticket_options[:event_end_date]
          interval["end"] = {
            "date" => ticket_options[:event_end_date]
          }
        end

        interval
      end

      def build_venue(ticket_options)
        return nil unless ticket_options[:venue_name]

        {
          "name" => build_localized_string(ticket_options[:venue_name]),
          "address" => build_localized_string(ticket_options[:venue_address])
        }.tap do |venue|
          if ticket_options[:latitude] && ticket_options[:longitude]
            venue["location"] = {
              "latitude" => ticket_options[:latitude],
              "longitude" => ticket_options[:longitude]
            }
          end
        end.compact
      end

      def build_seat_info(ticket_options)
        seat = {}
        seat["section"] = build_localized_string(ticket_options[:seat_section]) if ticket_options[:seat_section]
        seat["row"] = build_localized_string(ticket_options[:seat_row]) if ticket_options[:seat_row]
        seat["seat"] = build_localized_string(ticket_options[:seat_number]) if ticket_options[:seat_number]
        seat["gate"] = build_localized_string(ticket_options[:gate]) if ticket_options[:gate]

        seat.empty? ? nil : seat
      end

      def build_face_value(transaction)
        amount = transaction["billAmount"] || transaction["amount"]
        return nil unless amount

        {
          "currencyCode" => "MYR",
          "units" => (amount.to_i / 100).to_s,
          "nanos" => ((amount.to_i % 100) * 10_000_000)
        }
      end

      def build_image(uri, description)
        return nil unless uri

        {
          "sourceUri" => {
            "uri" => uri,
            "description" => description
          }
        }
      end

      def build_links(ticket_options)
        links = []

        if ticket_options[:website_url]
          links << {
            "uri" => ticket_options[:website_url],
            "description" => "Event Website"
          }
        end

        if ticket_options[:map_url]
          links << {
            "uri" => ticket_options[:map_url],
            "description" => "Venue Map"
          }
        end

        links.empty? ? nil : { "uris" => links }
      end

      def build_text_modules(transaction, ticket_options)
        modules = []

        if ticket_options[:event_date]
          # Parse and format date
          begin
            date = Time.parse(ticket_options[:event_date])
            modules << {
              "id" => "date",
              "header" => "Date",
              "body" => date.strftime("%B %d, %Y")
            }
            modules << {
              "id" => "time",
              "header" => "Time",
              "body" => date.strftime("%I:%M %p")
            }
          rescue StandardError
            modules << {
              "id" => "date",
              "header" => "Date",
              "body" => ticket_options[:event_date]
            }
          end
        end

        if ticket_options[:custom_info]
          ticket_options[:custom_info].each_with_index do |(key, value), index|
            modules << {
              "id" => "custom_#{index}",
              "header" => key.to_s,
              "body" => value.to_s
            }
          end
        end

        modules.empty? ? nil : modules
      end

      def build_info_module(transaction, ticket_options)
        rows = []

        payer_email = transaction["billEmail"] || transaction["billpayorEmail"]
        if payer_email
          rows << {
            "label" => "Email",
            "value" => payer_email
          }
        end

        bill_code = extract_bill_code(transaction)
        rows << {
          "label" => "Reference",
          "value" => bill_code
        }

        if ticket_options[:terms]
          rows << {
            "label" => "Terms",
            "value" => ticket_options[:terms]
          }
        end

        { "labelValueRows" => rows, "showLastUpdateTime" => true }
      end

      def sign_jwt(payload)
        begin
          require "jwt"

          JWT.encode(
            payload,
            OpenSSL::PKey::RSA.new(@service_account_key["private_key"]),
            "RS256"
          )
        rescue LoadError
          raise ConfigurationError, "The 'jwt' gem is required for Google Wallet JWT generation. Add it to your Gemfile."
        rescue StandardError => e
          raise SigningError, "Failed to sign JWT: #{e.message}"
        end
      end

      # Custom errors
      class ConfigurationError < ToyyibPay::Error; end
      class SigningError < ToyyibPay::Error; end
    end
  end
end
