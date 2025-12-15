# frozen_string_literal: true

require "spec_helper"

RSpec.describe ToyyibPay::Wallet::GoogleWallet do
  let(:options) do
    {
      issuer_id: "3388000000012345678",
      organization_name: "Example Events"
    }
  end

  let(:wallet) { described_class.new(options) }

  let(:transaction) do
    {
      "BillCode" => "abc123xyz",
      "billName" => "Concert Ticket",
      "billTo" => "John Doe",
      "billEmail" => "john@example.com",
      "billAmount" => 15000
    }
  end

  describe "#initialize" do
    it "stores options" do
      expect(wallet.options[:issuer_id]).to eq("3388000000012345678")
      expect(wallet.options[:organization_name]).to eq("Example Events")
    end
  end

  describe "#generate_ticket" do
    it "generates valid ticket object structure" do
      ticket = wallet.generate_ticket(transaction)

      expect(ticket["id"]).to include(options[:issuer_id])
      expect(ticket["state"]).to eq("ACTIVE")
      expect(ticket["ticketHolderName"]).to eq("John Doe")
    end

    it "includes ticket number" do
      ticket = wallet.generate_ticket(transaction)

      expect(ticket["ticketNumber"]).to match(/^TKT-[A-F0-9]+$/)
    end

    it "includes QR barcode" do
      ticket = wallet.generate_ticket(transaction)

      expect(ticket["barcode"]["type"]).to eq("QR_CODE")
      expect(ticket["barcode"]["value"]).to eq("abc123xyz")
    end

    it "includes event name" do
      ticket = wallet.generate_ticket(transaction, event_name: "Rock Concert")

      event_name = ticket["eventName"]["defaultValue"]["value"]
      expect(event_name).to eq("Rock Concert")
    end

    it "includes venue information" do
      ticket = wallet.generate_ticket(transaction, {
        venue_name: "Stadium",
        venue_address: "123 Main St",
        latitude: 3.1579,
        longitude: 101.7116
      })

      expect(ticket["venue"]["name"]["defaultValue"]["value"]).to eq("Stadium")
      expect(ticket["venue"]["address"]["defaultValue"]["value"]).to eq("123 Main St")
      expect(ticket["venue"]["location"]["latitude"]).to eq(3.1579)
    end

    it "includes seat information" do
      ticket = wallet.generate_ticket(transaction, {
        seat_section: "A",
        seat_row: "5",
        seat_number: "12",
        gate: "North"
      })

      expect(ticket["seatInfo"]["section"]["defaultValue"]["value"]).to eq("A")
      expect(ticket["seatInfo"]["row"]["defaultValue"]["value"]).to eq("5")
      expect(ticket["seatInfo"]["seat"]["defaultValue"]["value"]).to eq("12")
      expect(ticket["seatInfo"]["gate"]["defaultValue"]["value"]).to eq("North")
    end

    it "includes face value" do
      ticket = wallet.generate_ticket(transaction)

      expect(ticket["faceValue"]["currencyCode"]).to eq("MYR")
      expect(ticket["faceValue"]["units"]).to eq("150")
    end

    it "includes time interval when event date provided" do
      ticket = wallet.generate_ticket(transaction, {
        event_date: "2024-03-15T20:00:00+08:00",
        event_end_date: "2024-03-15T23:00:00+08:00"
      })

      expect(ticket["validTimeInterval"]["start"]["date"]).to eq("2024-03-15T20:00:00+08:00")
      expect(ticket["validTimeInterval"]["end"]["date"]).to eq("2024-03-15T23:00:00+08:00")
    end

    it "includes custom info in text modules" do
      ticket = wallet.generate_ticket(transaction, {
        custom_info: {
          "Dress Code" => "Smart Casual",
          "Parking" => "Level 2"
        }
      })

      text_modules = ticket["textModulesData"]
      custom_modules = text_modules.select { |m| m["id"].start_with?("custom_") }

      expect(custom_modules.length).to eq(2)
    end

    it "includes logo when URI provided" do
      ticket = wallet.generate_ticket(transaction, {
        logo_uri: "https://example.com/logo.png"
      })

      expect(ticket["logo"]["sourceUri"]["uri"]).to eq("https://example.com/logo.png")
    end

    it "includes hero image when URI provided" do
      ticket = wallet.generate_ticket(transaction, {
        hero_image_uri: "https://example.com/hero.png"
      })

      expect(ticket["heroImage"]["sourceUri"]["uri"]).to eq("https://example.com/hero.png")
    end

    it "sets background color" do
      ticket = wallet.generate_ticket(transaction, hex_background_color: "#ff0000")

      expect(ticket["hexBackgroundColor"]).to eq("#ff0000")
    end
  end

  describe "#generate_class" do
    it "generates valid class structure" do
      ticket_class = wallet.generate_class

      expect(ticket_class["id"]).to include(options[:issuer_id])
      expect(ticket_class["issuerName"]).to eq("Example Events")
      expect(ticket_class["reviewStatus"]).to eq("DRAFT")
    end

    it "allows custom class ID" do
      ticket_class = wallet.generate_class(class_id: "custom.class.id")

      expect(ticket_class["id"]).to eq("custom.class.id")
    end

    it "allows custom event name" do
      ticket_class = wallet.generate_class(event_name: "Annual Gala")

      expect(ticket_class["eventName"]["defaultValue"]["value"]).to eq("Annual Gala")
    end

    it "sets review status" do
      ticket_class = wallet.generate_class(review_status: "APPROVED")

      expect(ticket_class["reviewStatus"]).to eq("APPROVED")
    end

    it "includes callback options when URL provided" do
      ticket_class = wallet.generate_class(callback_url: "https://example.com/callback")

      expect(ticket_class["callbackOptions"]["url"]).to eq("https://example.com/callback")
    end
  end

  describe "#to_hash" do
    it "returns both class and object" do
      result = wallet.to_hash(transaction, event_name: "Test Event")

      expect(result).to have_key(:class)
      expect(result).to have_key(:object)
      expect(result[:object]["eventName"]["defaultValue"]["value"]).to eq("Test Event")
    end
  end

  describe "#add_button_html" do
    context "without service account" do
      it "raises error when generating save URL" do
        expect { wallet.save_url(transaction) }.to raise_error(
          ToyyibPay::Wallet::GoogleWallet::ConfigurationError
        )
      end
    end
  end

  describe "#configured?" do
    it "returns false without service account key" do
      expect(wallet.configured?).to be false
    end
  end

  describe "edge cases" do
    it "handles transaction with missing fields" do
      minimal = { "BillCode" => "min123" }
      ticket = wallet.generate_ticket(minimal)

      expect(ticket["ticketHolderName"]).to eq("Guest")
    end

    it "handles missing venue info gracefully" do
      ticket = wallet.generate_ticket(transaction)

      expect(ticket["venue"]).to be_nil
    end

    it "handles missing seat info gracefully" do
      ticket = wallet.generate_ticket(transaction)

      expect(ticket["seatInfo"]).to be_nil
    end
  end
end
