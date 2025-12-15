# frozen_string_literal: true

require "base64"
require "erb"
require "time"

module ToyyibPay
  # Ticket generation module for creating HTML entry passes
  # Supports customizable templates and QR code integration
  module Ticket
    class << self
      # Generate an HTML ticket from transaction/bill data
      #
      # @param transaction [Hash] Transaction data from ToyyibPay
      # @param options [Hash] Customization options
      # @option options [String] :template Custom ERB template (optional)
      # @option options [String] :event_name Event/product name
      # @option options [String] :event_date Event date/time
      # @option options [String] :event_location Event location
      # @option options [String] :organizer_name Organizer name
      # @option options [String] :organizer_logo URL or base64 logo
      # @option options [String] :ticket_type Ticket type (e.g., "VIP", "General")
      # @option options [String] :seat_info Seat information
      # @option options [Hash] :custom_fields Additional custom fields to display
      # @option options [String] :theme Color theme (:default, :dark, :minimal)
      # @option options [Boolean] :include_qr Include QR code (default: true)
      # @option options [String] :qr_data Custom QR code data (defaults to bill_code)
      #
      # @return [String] HTML ticket content
      #
      # @example
      #   html = ToyyibPay::Ticket.generate(
      #     transaction,
      #     event_name: "Tech Conference 2024",
      #     event_date: "2024-03-15 09:00",
      #     event_location: "KLCC Convention Center",
      #     ticket_type: "VIP Pass"
      #   )
      def generate(transaction, options = {})
        ticket_data = build_ticket_data(transaction, options)
        template = options[:template] || default_template(options[:theme] || :default)

        erb = ERB.new(template, trim_mode: "-")
        erb.result_with_hash(ticket_data)
      end

      # Generate and save HTML ticket to a file
      #
      # @param transaction [Hash] Transaction data
      # @param filepath [String] Output file path
      # @param options [Hash] Customization options (same as #generate)
      #
      # @return [String] File path
      def generate_to_file(transaction, filepath, options = {})
        html = generate(transaction, options)
        File.write(filepath, html)
        filepath
      end

      # Generate multiple tickets for batch processing
      #
      # @param transactions [Array<Hash>] Array of transaction data
      # @param options [Hash] Shared customization options
      #
      # @return [Array<String>] Array of HTML ticket contents
      def generate_batch(transactions, options = {})
        transactions.map { |txn| generate(txn, options) }
      end

      private

      def build_ticket_data(transaction, options)
        bill_code = extract_bill_code(transaction)

        {
          # Transaction data
          bill_code: bill_code,
          transaction_id: transaction["billExternalReferenceNo"] || transaction["refno"] || bill_code,
          payer_name: transaction["billTo"] || transaction["billpayorName"] || "Guest",
          payer_email: transaction["billEmail"] || transaction["billpayorEmail"],
          payer_phone: transaction["billPhone"] || transaction["billpayorPhone"],
          amount: format_amount(transaction["billAmount"] || transaction["amount"]),
          currency: "MYR",
          payment_date: format_date(transaction["billPaymentDate"] || transaction["transactionDate"] || Time.now),
          payment_status: transaction["billStatus"] || transaction["status"] || "Paid",

          # Event/ticket data from options
          event_name: options[:event_name] || transaction["billName"] || "Entry Pass",
          event_description: options[:event_description] || transaction["billDescription"],
          event_date: options[:event_date],
          event_time: options[:event_time],
          event_location: options[:event_location],
          venue_details: options[:venue_details],

          # Organizer data
          organizer_name: options[:organizer_name] || "ToyyibPay",
          organizer_logo: options[:organizer_logo],
          organizer_contact: options[:organizer_contact],

          # Ticket specifics
          ticket_type: options[:ticket_type] || "General Admission",
          ticket_number: generate_ticket_number(bill_code),
          seat_info: options[:seat_info],
          gate_info: options[:gate_info],

          # Custom fields
          custom_fields: options[:custom_fields] || {},

          # QR code
          include_qr: options.fetch(:include_qr, true),
          qr_data: options[:qr_data] || bill_code,
          qr_svg: options.fetch(:include_qr, true) ? generate_qr_svg(options[:qr_data] || bill_code) : nil,

          # Metadata
          generated_at: Time.now.utc.iso8601,
          theme: options[:theme] || :default,

          # Terms and conditions
          terms: options[:terms],
          refund_policy: options[:refund_policy]
        }
      end

      def extract_bill_code(transaction)
        transaction["BillCode"] || transaction["billCode"] || transaction["bill_code"] || "UNKNOWN"
      end

      def format_amount(amount)
        return "0.00" unless amount

        # ToyyibPay amounts are in cents
        cents = amount.to_i
        format("%.2f", cents / 100.0)
      end

      def format_date(date)
        return nil unless date

        parsed = date.is_a?(String) ? Time.parse(date) : date
        parsed.strftime("%d %B %Y, %I:%M %p")
      rescue StandardError
        date.to_s
      end

      def generate_ticket_number(bill_code)
        # Generate a readable ticket number from bill code
        hash = Digest::SHA256.hexdigest(bill_code)[0..7].upcase
        "TKT-#{hash}"
      end

      def generate_qr_svg(data)
        # Check if rqrcode is available
        begin
          require "rqrcode"
          qr = RQRCode::QRCode.new(data.to_s, level: :m)
          qr.as_svg(
            color: "000",
            shape_rendering: "crispEdges",
            module_size: 4,
            standalone: true,
            use_path: true,
            viewbox: true
          )
        rescue LoadError
          # Fallback: return a placeholder if rqrcode is not installed
          generate_qr_placeholder(data)
        rescue StandardError => e
          ToyyibPay.logger&.warn("QR code generation failed: #{e.message}")
          generate_qr_placeholder(data)
        end
      end

      def generate_qr_placeholder(data)
        # SVG placeholder when QR code gem is not available
        <<~SVG
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">
            <rect width="200" height="200" fill="#f5f5f5" stroke="#ddd" stroke-width="2"/>
            <text x="100" y="90" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#666">
              QR Code
            </text>
            <text x="100" y="110" text-anchor="middle" font-family="monospace" font-size="10" fill="#999">
              #{CGI.escapeHTML(data.to_s[0..15])}#{data.to_s.length > 15 ? "..." : ""}
            </text>
            <text x="100" y="140" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="#999">
              (Install rqrcode gem)
            </text>
          </svg>
        SVG
      end

      def default_template(theme)
        case theme
        when :dark
          dark_template
        when :minimal
          minimal_template
        else
          default_light_template
        end
      end

      def default_light_template
        <<~ERB
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Entry Pass - <%= event_name %></title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
                display: flex;
                justify-content: center;
                align-items: center;
              }
              .ticket {
                background: white;
                border-radius: 20px;
                max-width: 420px;
                width: 100%;
                box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                overflow: hidden;
                position: relative;
              }
              .ticket-header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 30px 25px;
                text-align: center;
              }
              .organizer-logo {
                max-height: 50px;
                max-width: 150px;
                margin-bottom: 15px;
              }
              .event-name {
                font-size: 24px;
                font-weight: 700;
                margin-bottom: 5px;
                letter-spacing: -0.5px;
              }
              .ticket-type {
                display: inline-block;
                background: rgba(255,255,255,0.2);
                padding: 6px 16px;
                border-radius: 20px;
                font-size: 13px;
                font-weight: 600;
                margin-top: 10px;
                text-transform: uppercase;
                letter-spacing: 1px;
              }
              .ticket-body {
                padding: 25px;
              }
              .ticket-number {
                text-align: center;
                padding: 15px;
                background: #f8f9fa;
                border-radius: 12px;
                margin-bottom: 20px;
              }
              .ticket-number-label {
                font-size: 11px;
                color: #6b7280;
                text-transform: uppercase;
                letter-spacing: 1px;
                margin-bottom: 5px;
              }
              .ticket-number-value {
                font-size: 20px;
                font-weight: 700;
                color: #1f2937;
                font-family: 'SF Mono', Monaco, monospace;
                letter-spacing: 2px;
              }
              .info-grid {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 20px;
                margin-bottom: 20px;
              }
              .info-item {
                padding: 0;
              }
              .info-item.full-width {
                grid-column: span 2;
              }
              .info-label {
                font-size: 11px;
                color: #6b7280;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 4px;
              }
              .info-value {
                font-size: 15px;
                color: #1f2937;
                font-weight: 500;
              }
              .qr-section {
                text-align: center;
                padding: 20px;
                background: #f8f9fa;
                border-radius: 12px;
                margin-top: 20px;
              }
              .qr-code {
                display: inline-block;
                padding: 15px;
                background: white;
                border-radius: 12px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.08);
              }
              .qr-code svg {
                width: 150px;
                height: 150px;
              }
              .qr-instruction {
                font-size: 12px;
                color: #6b7280;
                margin-top: 12px;
              }
              .divider {
                position: relative;
                margin: 25px 0;
                border: none;
              }
              .divider::before {
                content: '';
                position: absolute;
                left: 0;
                right: 0;
                top: 50%;
                border-top: 2px dashed #e5e7eb;
              }
              .divider::after {
                content: '✂';
                position: absolute;
                left: 50%;
                top: 50%;
                transform: translate(-50%, -50%);
                background: white;
                padding: 0 10px;
                color: #9ca3af;
              }
              .ticket-footer {
                padding: 20px 25px;
                background: #f8f9fa;
                text-align: center;
                font-size: 11px;
                color: #6b7280;
              }
              .status-badge {
                display: inline-block;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
                text-transform: uppercase;
              }
              .status-paid {
                background: #d1fae5;
                color: #065f46;
              }
              .status-pending {
                background: #fef3c7;
                color: #92400e;
              }
              .custom-fields {
                margin-top: 20px;
                padding-top: 20px;
                border-top: 1px solid #e5e7eb;
              }
              @media print {
                body { background: white; padding: 0; }
                .ticket { box-shadow: none; max-width: 100%; }
              }
            </style>
          </head>
          <body>
            <div class="ticket">
              <div class="ticket-header">
                <% if organizer_logo %>
                  <img src="<%= organizer_logo %>" alt="<%= organizer_name %>" class="organizer-logo">
                <% end %>
                <div class="event-name"><%= event_name %></div>
                <% if event_description %>
                  <div style="font-size: 14px; opacity: 0.9; margin-top: 5px;"><%= event_description %></div>
                <% end %>
                <div class="ticket-type"><%= ticket_type %></div>
              </div>

              <div class="ticket-body">
                <div class="ticket-number">
                  <div class="ticket-number-label">Ticket Number</div>
                  <div class="ticket-number-value"><%= ticket_number %></div>
                </div>

                <div class="info-grid">
                  <div class="info-item">
                    <div class="info-label">Attendee</div>
                    <div class="info-value"><%= payer_name %></div>
                  </div>
                  <div class="info-item">
                    <div class="info-label">Status</div>
                    <div class="info-value">
                      <span class="status-badge <%= payment_status.to_s.downcase.include?('paid') || payment_status == '1' ? 'status-paid' : 'status-pending' %>">
                        <%= payment_status.to_s.downcase.include?('paid') || payment_status == '1' ? 'Confirmed' : payment_status %>
                      </span>
                    </div>
                  </div>
                  <% if event_date %>
                    <div class="info-item">
                      <div class="info-label">Date</div>
                      <div class="info-value"><%= event_date %></div>
                    </div>
                  <% end %>
                  <% if event_time %>
                    <div class="info-item">
                      <div class="info-label">Time</div>
                      <div class="info-value"><%= event_time %></div>
                    </div>
                  <% end %>
                  <% if event_location %>
                    <div class="info-item full-width">
                      <div class="info-label">Location</div>
                      <div class="info-value"><%= event_location %></div>
                    </div>
                  <% end %>
                  <% if seat_info %>
                    <div class="info-item">
                      <div class="info-label">Seat</div>
                      <div class="info-value"><%= seat_info %></div>
                    </div>
                  <% end %>
                  <% if gate_info %>
                    <div class="info-item">
                      <div class="info-label">Gate</div>
                      <div class="info-value"><%= gate_info %></div>
                    </div>
                  <% end %>
                  <div class="info-item">
                    <div class="info-label">Amount Paid</div>
                    <div class="info-value"><%= currency %> <%= amount %></div>
                  </div>
                  <div class="info-item">
                    <div class="info-label">Reference</div>
                    <div class="info-value" style="font-family: monospace; font-size: 13px;"><%= transaction_id %></div>
                  </div>
                </div>

                <% unless custom_fields.empty? %>
                  <div class="custom-fields">
                    <div class="info-grid">
                      <% custom_fields.each do |label, value| %>
                        <div class="info-item">
                          <div class="info-label"><%= label %></div>
                          <div class="info-value"><%= value %></div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <% if include_qr %>
                  <hr class="divider">
                  <div class="qr-section">
                    <div class="qr-code">
                      <%= qr_svg %>
                    </div>
                    <div class="qr-instruction">Scan this QR code at the entrance</div>
                  </div>
                <% end %>
              </div>

              <div class="ticket-footer">
                <% if terms %>
                  <p style="margin-bottom: 10px;"><%= terms %></p>
                <% end %>
                <p>Organized by <%= organizer_name %></p>
                <p style="margin-top: 5px;">Generated on <%= generated_at %></p>
              </div>
            </div>
          </body>
          </html>
        ERB
      end

      def dark_template
        <<~ERB
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Entry Pass - <%= event_name %></title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: #0f0f0f;
                min-height: 100vh;
                padding: 20px;
                display: flex;
                justify-content: center;
                align-items: center;
              }
              .ticket {
                background: #1a1a1a;
                border-radius: 20px;
                max-width: 420px;
                width: 100%;
                box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                overflow: hidden;
                border: 1px solid #333;
              }
              .ticket-header {
                background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                color: #e0e0e0;
                padding: 30px 25px;
                text-align: center;
                border-bottom: 1px solid #333;
              }
              .organizer-logo {
                max-height: 50px;
                max-width: 150px;
                margin-bottom: 15px;
                filter: brightness(0.9);
              }
              .event-name {
                font-size: 24px;
                font-weight: 700;
                margin-bottom: 5px;
                color: #fff;
              }
              .ticket-type {
                display: inline-block;
                background: rgba(255,255,255,0.1);
                padding: 6px 16px;
                border-radius: 20px;
                font-size: 13px;
                font-weight: 600;
                margin-top: 10px;
                text-transform: uppercase;
                letter-spacing: 1px;
                border: 1px solid rgba(255,255,255,0.2);
              }
              .ticket-body {
                padding: 25px;
              }
              .ticket-number {
                text-align: center;
                padding: 15px;
                background: #252525;
                border-radius: 12px;
                margin-bottom: 20px;
                border: 1px solid #333;
              }
              .ticket-number-label {
                font-size: 11px;
                color: #888;
                text-transform: uppercase;
                letter-spacing: 1px;
                margin-bottom: 5px;
              }
              .ticket-number-value {
                font-size: 20px;
                font-weight: 700;
                color: #00d4aa;
                font-family: 'SF Mono', Monaco, monospace;
                letter-spacing: 2px;
              }
              .info-grid {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 20px;
                margin-bottom: 20px;
              }
              .info-item.full-width {
                grid-column: span 2;
              }
              .info-label {
                font-size: 11px;
                color: #666;
                text-transform: uppercase;
                letter-spacing: 0.5px;
                margin-bottom: 4px;
              }
              .info-value {
                font-size: 15px;
                color: #e0e0e0;
                font-weight: 500;
              }
              .qr-section {
                text-align: center;
                padding: 20px;
                background: #252525;
                border-radius: 12px;
                margin-top: 20px;
                border: 1px solid #333;
              }
              .qr-code {
                display: inline-block;
                padding: 15px;
                background: white;
                border-radius: 12px;
              }
              .qr-code svg {
                width: 150px;
                height: 150px;
              }
              .qr-instruction {
                font-size: 12px;
                color: #888;
                margin-top: 12px;
              }
              .divider {
                position: relative;
                margin: 25px 0;
                border: none;
              }
              .divider::before {
                content: '';
                position: absolute;
                left: 0;
                right: 0;
                top: 50%;
                border-top: 2px dashed #333;
              }
              .divider::after {
                content: '✂';
                position: absolute;
                left: 50%;
                top: 50%;
                transform: translate(-50%, -50%);
                background: #1a1a1a;
                padding: 0 10px;
                color: #555;
              }
              .ticket-footer {
                padding: 20px 25px;
                background: #151515;
                text-align: center;
                font-size: 11px;
                color: #666;
                border-top: 1px solid #333;
              }
              .status-badge {
                display: inline-block;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
                text-transform: uppercase;
              }
              .status-paid {
                background: rgba(0, 212, 170, 0.2);
                color: #00d4aa;
                border: 1px solid rgba(0, 212, 170, 0.3);
              }
              .status-pending {
                background: rgba(255, 193, 7, 0.2);
                color: #ffc107;
                border: 1px solid rgba(255, 193, 7, 0.3);
              }
              @media print {
                body { background: white; }
                .ticket { background: white; border: 1px solid #ddd; }
                .ticket-header { background: #333; }
                .ticket-body, .ticket-footer { background: white; }
                .info-value, .event-name { color: #333; }
              }
            </style>
          </head>
          <body>
            <div class="ticket">
              <div class="ticket-header">
                <% if organizer_logo %>
                  <img src="<%= organizer_logo %>" alt="<%= organizer_name %>" class="organizer-logo">
                <% end %>
                <div class="event-name"><%= event_name %></div>
                <% if event_description %>
                  <div style="font-size: 14px; opacity: 0.8; margin-top: 5px;"><%= event_description %></div>
                <% end %>
                <div class="ticket-type"><%= ticket_type %></div>
              </div>

              <div class="ticket-body">
                <div class="ticket-number">
                  <div class="ticket-number-label">Ticket Number</div>
                  <div class="ticket-number-value"><%= ticket_number %></div>
                </div>

                <div class="info-grid">
                  <div class="info-item">
                    <div class="info-label">Attendee</div>
                    <div class="info-value"><%= payer_name %></div>
                  </div>
                  <div class="info-item">
                    <div class="info-label">Status</div>
                    <div class="info-value">
                      <span class="status-badge <%= payment_status.to_s.downcase.include?('paid') || payment_status == '1' ? 'status-paid' : 'status-pending' %>">
                        <%= payment_status.to_s.downcase.include?('paid') || payment_status == '1' ? 'Confirmed' : payment_status %>
                      </span>
                    </div>
                  </div>
                  <% if event_date %>
                    <div class="info-item">
                      <div class="info-label">Date</div>
                      <div class="info-value"><%= event_date %></div>
                    </div>
                  <% end %>
                  <% if event_time %>
                    <div class="info-item">
                      <div class="info-label">Time</div>
                      <div class="info-value"><%= event_time %></div>
                    </div>
                  <% end %>
                  <% if event_location %>
                    <div class="info-item full-width">
                      <div class="info-label">Location</div>
                      <div class="info-value"><%= event_location %></div>
                    </div>
                  <% end %>
                  <% if seat_info %>
                    <div class="info-item">
                      <div class="info-label">Seat</div>
                      <div class="info-value"><%= seat_info %></div>
                    </div>
                  <% end %>
                  <% if gate_info %>
                    <div class="info-item">
                      <div class="info-label">Gate</div>
                      <div class="info-value"><%= gate_info %></div>
                    </div>
                  <% end %>
                  <div class="info-item">
                    <div class="info-label">Amount Paid</div>
                    <div class="info-value"><%= currency %> <%= amount %></div>
                  </div>
                  <div class="info-item">
                    <div class="info-label">Reference</div>
                    <div class="info-value" style="font-family: monospace; font-size: 13px;"><%= transaction_id %></div>
                  </div>
                </div>

                <% unless custom_fields.empty? %>
                  <div style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #333;">
                    <div class="info-grid">
                      <% custom_fields.each do |label, value| %>
                        <div class="info-item">
                          <div class="info-label"><%= label %></div>
                          <div class="info-value"><%= value %></div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <% if include_qr %>
                  <hr class="divider">
                  <div class="qr-section">
                    <div class="qr-code">
                      <%= qr_svg %>
                    </div>
                    <div class="qr-instruction">Scan this QR code at the entrance</div>
                  </div>
                <% end %>
              </div>

              <div class="ticket-footer">
                <% if terms %>
                  <p style="margin-bottom: 10px;"><%= terms %></p>
                <% end %>
                <p>Organized by <%= organizer_name %></p>
                <p style="margin-top: 5px;">Generated on <%= generated_at %></p>
              </div>
            </div>
          </body>
          </html>
        ERB
      end

      def minimal_template
        <<~ERB
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Entry Pass - <%= event_name %></title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: #fafafa;
                min-height: 100vh;
                padding: 20px;
                display: flex;
                justify-content: center;
                align-items: center;
              }
              .ticket {
                background: white;
                max-width: 380px;
                width: 100%;
                border: 2px solid #000;
              }
              .ticket-header {
                background: #000;
                color: white;
                padding: 25px 20px;
                text-align: center;
              }
              .event-name {
                font-size: 20px;
                font-weight: 700;
                text-transform: uppercase;
                letter-spacing: 2px;
              }
              .ticket-type {
                font-size: 12px;
                margin-top: 8px;
                letter-spacing: 3px;
                opacity: 0.8;
              }
              .ticket-body {
                padding: 25px 20px;
              }
              .ticket-number {
                text-align: center;
                padding: 20px;
                border: 2px dashed #000;
                margin-bottom: 25px;
              }
              .ticket-number-label {
                font-size: 10px;
                text-transform: uppercase;
                letter-spacing: 2px;
                margin-bottom: 8px;
              }
              .ticket-number-value {
                font-size: 24px;
                font-weight: 700;
                font-family: 'Courier New', monospace;
                letter-spacing: 3px;
              }
              .info-row {
                display: flex;
                justify-content: space-between;
                padding: 12px 0;
                border-bottom: 1px solid #eee;
              }
              .info-row:last-child {
                border-bottom: none;
              }
              .info-label {
                font-size: 11px;
                text-transform: uppercase;
                letter-spacing: 1px;
                color: #666;
              }
              .info-value {
                font-size: 14px;
                font-weight: 600;
                text-align: right;
              }
              .qr-section {
                text-align: center;
                margin-top: 25px;
                padding-top: 25px;
                border-top: 2px dashed #000;
              }
              .qr-code svg {
                width: 140px;
                height: 140px;
              }
              .ticket-footer {
                padding: 15px 20px;
                background: #f5f5f5;
                text-align: center;
                font-size: 10px;
                text-transform: uppercase;
                letter-spacing: 1px;
                color: #666;
              }
              @media print {
                body { background: white; padding: 0; }
              }
            </style>
          </head>
          <body>
            <div class="ticket">
              <div class="ticket-header">
                <div class="event-name"><%= event_name %></div>
                <div class="ticket-type"><%= ticket_type %></div>
              </div>

              <div class="ticket-body">
                <div class="ticket-number">
                  <div class="ticket-number-label">Ticket No.</div>
                  <div class="ticket-number-value"><%= ticket_number %></div>
                </div>

                <div class="info-row">
                  <span class="info-label">Name</span>
                  <span class="info-value"><%= payer_name %></span>
                </div>
                <% if event_date %>
                  <div class="info-row">
                    <span class="info-label">Date</span>
                    <span class="info-value"><%= event_date %></span>
                  </div>
                <% end %>
                <% if event_location %>
                  <div class="info-row">
                    <span class="info-label">Venue</span>
                    <span class="info-value"><%= event_location %></span>
                  </div>
                <% end %>
                <% if seat_info %>
                  <div class="info-row">
                    <span class="info-label">Seat</span>
                    <span class="info-value"><%= seat_info %></span>
                  </div>
                <% end %>
                <div class="info-row">
                  <span class="info-label">Amount</span>
                  <span class="info-value"><%= currency %> <%= amount %></span>
                </div>
                <div class="info-row">
                  <span class="info-label">Ref</span>
                  <span class="info-value" style="font-family: monospace;"><%= transaction_id %></span>
                </div>

                <% if include_qr %>
                  <div class="qr-section">
                    <%= qr_svg %>
                  </div>
                <% end %>
              </div>

              <div class="ticket-footer">
                <%= organizer_name %>
              </div>
            </div>
          </body>
          </html>
        ERB
      end
    end
  end
end
