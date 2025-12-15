# frozen_string_literal: true

require "json"
require "digest"
require "base64"
require "fileutils"
require "tempfile"
require "time"

module ToyyibPay
  module Wallet
    # Apple Wallet (Passbook) integration for generating .pkpass files
    # Supports event tickets, boarding passes, coupons, store cards, and generic passes
    #
    # Note: To create valid passes that can be added to Apple Wallet, you need:
    # - Apple Developer account
    # - Pass Type ID certificate (.p12 or .pem)
    # - WWDR (Apple Worldwide Developer Relations) certificate
    #
    # Without signing, passes can be used for testing or previewing.
    class AppleWallet
      # Pass style types supported by Apple Wallet
      PASS_STYLES = %w[eventTicket boardingPass coupon storeCard generic].freeze

      # Default colors for passes
      DEFAULT_COLORS = {
        background: "rgb(60, 65, 76)",
        foreground: "rgb(255, 255, 255)",
        label: "rgb(198, 202, 213)"
      }.freeze

      attr_reader :pass_data, :options

      # Initialize a new Apple Wallet pass generator
      #
      # @param options [Hash] Pass configuration options
      # @option options [String] :pass_type_identifier Your Pass Type ID (required for signing)
      # @option options [String] :team_identifier Your Apple Team ID (required for signing)
      # @option options [String] :organization_name Organization name displayed on pass
      # @option options [String] :certificate_path Path to .p12 or .pem certificate
      # @option options [String] :certificate_password Password for the certificate
      # @option options [String] :wwdr_certificate_path Path to WWDR certificate
      #
      # @example
      #   wallet = ToyyibPay::Wallet::AppleWallet.new(
      #     pass_type_identifier: "pass.com.example.event",
      #     team_identifier: "ABCD1234",
      #     organization_name: "Example Events",
      #     certificate_path: "/path/to/pass.p12",
      #     certificate_password: "secret"
      #   )
      def initialize(options = {})
        @options = options
        @pass_data = {}
      end

      # Generate a pass from transaction data
      #
      # @param transaction [Hash] Transaction data from ToyyibPay
      # @param pass_options [Hash] Additional pass options
      # @option pass_options [String] :style Pass style (:event_ticket, :generic, etc.)
      # @option pass_options [String] :event_name Event name
      # @option pass_options [String] :event_date Event date (ISO 8601 format)
      # @option pass_options [String] :event_location Event location
      # @option pass_options [Hash] :locations Array of location hashes with :latitude, :longitude
      # @option pass_options [String] :background_color Background color (CSS rgb format)
      # @option pass_options [String] :foreground_color Foreground color
      # @option pass_options [String] :label_color Label color
      # @option pass_options [String] :logo_text Text displayed next to logo
      # @option pass_options [String] :icon_path Path to icon.png (required, 29x29 to 87x87)
      # @option pass_options [String] :logo_path Path to logo.png (optional)
      # @option pass_options [String] :strip_path Path to strip.png (optional, for event tickets)
      # @option pass_options [String] :thumbnail_path Path to thumbnail.png (optional)
      # @option pass_options [Boolean] :voided Whether the pass is voided
      # @option pass_options [Array<Hash>] :barcodes Barcode configurations
      #
      # @return [Hash] Pass data structure
      #
      # @example
      #   pass_data = wallet.generate_pass(transaction, {
      #     style: :event_ticket,
      #     event_name: "Tech Conference 2024",
      #     event_date: "2024-03-15T09:00:00+08:00",
      #     event_location: "KLCC Convention Center"
      #   })
      def generate_pass(transaction, pass_options = {})
        style = normalize_style(pass_options[:style] || :event_ticket)
        bill_code = extract_bill_code(transaction)

        @pass_data = {
          "formatVersion" => 1,
          "passTypeIdentifier" => options[:pass_type_identifier] || "pass.com.toyyibpay.event",
          "serialNumber" => generate_serial_number(bill_code),
          "teamIdentifier" => options[:team_identifier] || "TEAM_ID",
          "organizationName" => options[:organization_name] || "ToyyibPay",
          "description" => pass_options[:event_name] || transaction["billName"] || "Entry Pass",
          "logoText" => pass_options[:logo_text] || options[:organization_name] || "ToyyibPay",

          # Colors
          "backgroundColor" => pass_options[:background_color] || DEFAULT_COLORS[:background],
          "foregroundColor" => pass_options[:foreground_color] || DEFAULT_COLORS[:foreground],
          "labelColor" => pass_options[:label_color] || DEFAULT_COLORS[:label],

          # Barcode
          "barcodes" => pass_options[:barcodes] || [
            {
              "format" => "PKBarcodeFormatQR",
              "message" => bill_code,
              "messageEncoding" => "iso-8859-1",
              "altText" => bill_code
            }
          ],

          # Pass style content
          style => build_pass_fields(transaction, pass_options)
        }

        # Add relevant date if provided
        if pass_options[:event_date]
          @pass_data["relevantDate"] = pass_options[:event_date]
        end

        # Add locations for lock screen relevance
        if pass_options[:locations]
          @pass_data["locations"] = pass_options[:locations].map do |loc|
            {
              "latitude" => loc[:latitude],
              "longitude" => loc[:longitude],
              "relevantText" => loc[:relevant_text]
            }.compact
          end
        end

        # Add expiration if provided
        if pass_options[:expiration_date]
          @pass_data["expirationDate"] = pass_options[:expiration_date]
        end

        # Voided pass
        @pass_data["voided"] = true if pass_options[:voided]

        # Web service for updates (optional)
        if options[:web_service_url]
          @pass_data["webServiceURL"] = options[:web_service_url]
          @pass_data["authenticationToken"] = options[:auth_token] || generate_auth_token(bill_code)
        end

        @pass_data
      end

      # Generate a .pkpass file
      #
      # @param transaction [Hash] Transaction data
      # @param output_path [String] Output file path (without extension)
      # @param pass_options [Hash] Pass options (same as #generate_pass)
      #
      # @return [String] Path to generated .pkpass file
      #
      # @example
      #   path = wallet.generate_pkpass(transaction, "/tmp/ticket", {
      #     style: :event_ticket,
      #     event_name: "Concert",
      #     icon_path: "/path/to/icon.png"
      #   })
      def generate_pkpass(transaction, output_path, pass_options = {})
        generate_pass(transaction, pass_options)

        Dir.mktmpdir("pkpass") do |tmpdir|
          # Write pass.json
          pass_json_path = File.join(tmpdir, "pass.json")
          File.write(pass_json_path, JSON.pretty_generate(@pass_data))

          # Copy image assets
          copy_image_assets(tmpdir, pass_options)

          # Generate manifest
          manifest = generate_manifest(tmpdir)
          manifest_path = File.join(tmpdir, "manifest.json")
          File.write(manifest_path, JSON.pretty_generate(manifest))

          # Sign the pass if certificates are available
          if can_sign?
            sign_pass(tmpdir)
          else
            ToyyibPay.logger&.warn("Pass will not be signed - certificates not configured")
          end

          # Create the .pkpass file (ZIP archive)
          pkpass_path = "#{output_path}.pkpass"
          create_pkpass_archive(tmpdir, pkpass_path)

          pkpass_path
        end
      end

      # Generate pass data as a hash (for API responses)
      #
      # @param transaction [Hash] Transaction data
      # @param pass_options [Hash] Pass options
      #
      # @return [Hash] Pass data suitable for JSON serialization
      def to_hash(transaction, pass_options = {})
        generate_pass(transaction, pass_options)
        @pass_data
      end

      # Check if signing is configured
      #
      # @return [Boolean]
      def can_sign?
        options[:certificate_path] &&
          File.exist?(options[:certificate_path].to_s) &&
          options[:wwdr_certificate_path] &&
          File.exist?(options[:wwdr_certificate_path].to_s)
      end

      private

      def normalize_style(style)
        style_str = style.to_s
        # Convert snake_case to camelCase
        normalized = style_str.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
        PASS_STYLES.include?(normalized) ? normalized : "eventTicket"
      end

      def extract_bill_code(transaction)
        transaction["BillCode"] || transaction["billCode"] || transaction["bill_code"] || "UNKNOWN"
      end

      def generate_serial_number(bill_code)
        "TYP-#{Digest::SHA256.hexdigest(bill_code)[0..11].upcase}"
      end

      def generate_auth_token(bill_code)
        Digest::SHA256.hexdigest("#{bill_code}#{Time.now.to_i}")[0..31]
      end

      def build_pass_fields(transaction, pass_options)
        bill_code = extract_bill_code(transaction)

        fields = {
          "headerFields" => [],
          "primaryFields" => [],
          "secondaryFields" => [],
          "auxiliaryFields" => [],
          "backFields" => []
        }

        # Primary: Event name
        fields["primaryFields"] << {
          "key" => "event",
          "label" => "EVENT",
          "value" => pass_options[:event_name] || transaction["billName"] || "Entry Pass"
        }

        # Secondary: Date and Location
        if pass_options[:event_date]
          fields["secondaryFields"] << {
            "key" => "date",
            "label" => "DATE",
            "value" => pass_options[:event_date],
            "dateStyle" => "PKDateStyleMedium",
            "timeStyle" => "PKDateStyleShort"
          }
        end

        if pass_options[:event_location]
          fields["secondaryFields"] << {
            "key" => "location",
            "label" => "LOCATION",
            "value" => pass_options[:event_location]
          }
        end

        # Auxiliary: Ticket type, seat info
        if pass_options[:ticket_type]
          fields["auxiliaryFields"] << {
            "key" => "ticketType",
            "label" => "TYPE",
            "value" => pass_options[:ticket_type]
          }
        end

        if pass_options[:seat_info]
          fields["auxiliaryFields"] << {
            "key" => "seat",
            "label" => "SEAT",
            "value" => pass_options[:seat_info]
          }
        end

        if pass_options[:gate_info]
          fields["auxiliaryFields"] << {
            "key" => "gate",
            "label" => "GATE",
            "value" => pass_options[:gate_info]
          }
        end

        # Header: Attendee name
        payer_name = transaction["billTo"] || transaction["billpayorName"] || "Guest"
        fields["headerFields"] << {
          "key" => "attendee",
          "label" => "ATTENDEE",
          "value" => payer_name
        }

        # Back fields: Full details
        fields["backFields"] = [
          {
            "key" => "ticketNumber",
            "label" => "Ticket Number",
            "value" => "TKT-#{Digest::SHA256.hexdigest(bill_code)[0..7].upcase}"
          },
          {
            "key" => "reference",
            "label" => "Reference",
            "value" => bill_code
          },
          {
            "key" => "purchaser",
            "label" => "Purchaser",
            "value" => payer_name
          }
        ]

        if transaction["billEmail"] || transaction["billpayorEmail"]
          fields["backFields"] << {
            "key" => "email",
            "label" => "Email",
            "value" => transaction["billEmail"] || transaction["billpayorEmail"]
          }
        end

        amount = transaction["billAmount"] || transaction["amount"]
        if amount
          fields["backFields"] << {
            "key" => "amount",
            "label" => "Amount Paid",
            "value" => "MYR #{format("%.2f", amount.to_i / 100.0)}"
          }
        end

        if pass_options[:terms]
          fields["backFields"] << {
            "key" => "terms",
            "label" => "Terms & Conditions",
            "value" => pass_options[:terms]
          }
        end

        fields["backFields"] << {
          "key" => "support",
          "label" => "Support",
          "value" => pass_options[:support_info] || "Contact the event organizer for assistance."
        }

        fields
      end

      def copy_image_assets(tmpdir, pass_options)
        # Required: icon.png
        if pass_options[:icon_path] && File.exist?(pass_options[:icon_path])
          FileUtils.cp(pass_options[:icon_path], File.join(tmpdir, "icon.png"))
          # Also copy @2x and @3x if available
          copy_retina_image(pass_options[:icon_path], tmpdir, "icon")
        else
          # Generate a placeholder icon
          generate_placeholder_icon(tmpdir)
        end

        # Optional: logo.png
        if pass_options[:logo_path] && File.exist?(pass_options[:logo_path])
          FileUtils.cp(pass_options[:logo_path], File.join(tmpdir, "logo.png"))
          copy_retina_image(pass_options[:logo_path], tmpdir, "logo")
        end

        # Optional: strip.png (for event tickets)
        if pass_options[:strip_path] && File.exist?(pass_options[:strip_path])
          FileUtils.cp(pass_options[:strip_path], File.join(tmpdir, "strip.png"))
          copy_retina_image(pass_options[:strip_path], tmpdir, "strip")
        end

        # Optional: thumbnail.png
        if pass_options[:thumbnail_path] && File.exist?(pass_options[:thumbnail_path])
          FileUtils.cp(pass_options[:thumbnail_path], File.join(tmpdir, "thumbnail.png"))
          copy_retina_image(pass_options[:thumbnail_path], tmpdir, "thumbnail")
        end

        # Optional: background.png
        if pass_options[:background_path] && File.exist?(pass_options[:background_path])
          FileUtils.cp(pass_options[:background_path], File.join(tmpdir, "background.png"))
          copy_retina_image(pass_options[:background_path], tmpdir, "background")
        end
      end

      def copy_retina_image(original_path, tmpdir, base_name)
        dir = File.dirname(original_path)
        ext = File.extname(original_path)
        base = File.basename(original_path, ext)

        %w[@2x @3x].each do |suffix|
          retina_path = File.join(dir, "#{base}#{suffix}#{ext}")
          if File.exist?(retina_path)
            FileUtils.cp(retina_path, File.join(tmpdir, "#{base_name}#{suffix}#{ext}"))
          end
        end
      end

      def generate_placeholder_icon(tmpdir)
        # Create a minimal valid PNG file (1x1 pixel, transparent)
        # This is a base64-encoded minimal PNG
        png_data = Base64.decode64(
          "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAdCAYAAABWk2cPAAAADklEQVRIiWNgGAWjYGgBAAKdAAGFhJLfAAAAAElFTkSuQmCC"
        )
        File.binwrite(File.join(tmpdir, "icon.png"), png_data)
      end

      def generate_manifest(tmpdir)
        manifest = {}
        Dir.glob(File.join(tmpdir, "*")).each do |file|
          next if File.directory?(file)

          filename = File.basename(file)
          next if %w[manifest.json signature].include?(filename)

          content = File.binread(file)
          manifest[filename] = Digest::SHA1.hexdigest(content)
        end
        manifest
      end

      def sign_pass(tmpdir)
        return unless can_sign?

        begin
          require "openssl"

          manifest_path = File.join(tmpdir, "manifest.json")
          manifest_data = File.read(manifest_path)

          # Load certificates
          p12 = if options[:certificate_path].end_with?(".p12")
                  OpenSSL::PKCS12.new(
                    File.binread(options[:certificate_path]),
                    options[:certificate_password]
                  )
                else
                  nil
                end

          cert = p12&.certificate || OpenSSL::X509::Certificate.new(File.read(options[:certificate_path]))
          key = p12&.key || OpenSSL::PKey::RSA.new(File.read(options[:certificate_path]), options[:certificate_password])
          wwdr = OpenSSL::X509::Certificate.new(File.read(options[:wwdr_certificate_path]))

          # Create PKCS7 signature
          signature = OpenSSL::PKCS7.sign(cert, key, manifest_data, [wwdr], OpenSSL::PKCS7::BINARY | OpenSSL::PKCS7::DETACHED)

          File.binwrite(File.join(tmpdir, "signature"), signature.to_der)
        rescue StandardError => e
          ToyyibPay.logger&.error("Failed to sign pass: #{e.message}")
          raise SigningError, "Failed to sign pass: #{e.message}"
        end
      end

      def create_pkpass_archive(tmpdir, output_path)
        require "zip" if defined?(Zip)

        # Try using rubyzip if available
        if defined?(Zip::File)
          Zip::File.open(output_path, Zip::File::CREATE) do |zipfile|
            Dir.glob(File.join(tmpdir, "*")).each do |file|
              next if File.directory?(file)

              zipfile.add(File.basename(file), file)
            end
          end
        else
          # Fallback to system zip command
          original_dir = Dir.pwd
          begin
            Dir.chdir(tmpdir)
            system("zip", "-q", "-r", output_path, ".")
          ensure
            Dir.chdir(original_dir)
          end
        end

        output_path
      end

      # Custom error for signing failures
      class SigningError < ToyyibPay::Error; end
    end
  end
end
