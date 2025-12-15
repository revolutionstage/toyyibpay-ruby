# frozen_string_literal: true

require "spec_helper"

RSpec.describe ToyyibPay::Wallet::AppleWallet do
  let(:options) do
    {
      pass_type_identifier: "pass.com.example.event",
      team_identifier: "ABCD1234",
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
      expect(wallet.options[:pass_type_identifier]).to eq("pass.com.example.event")
      expect(wallet.options[:team_identifier]).to eq("ABCD1234")
    end
  end

  describe "#generate_pass" do
    it "generates valid pass structure" do
      pass = wallet.generate_pass(transaction)

      expect(pass["formatVersion"]).to eq(1)
      expect(pass["passTypeIdentifier"]).to eq("pass.com.example.event")
      expect(pass["teamIdentifier"]).to eq("ABCD1234")
      expect(pass["organizationName"]).to eq("Example Events")
    end

    it "includes serial number" do
      pass = wallet.generate_pass(transaction)

      expect(pass["serialNumber"]).to match(/^TYP-[A-F0-9]+$/)
    end

    it "includes barcode with bill code" do
      pass = wallet.generate_pass(transaction)

      expect(pass["barcodes"]).to be_an(Array)
      expect(pass["barcodes"].first["format"]).to eq("PKBarcodeFormatQR")
      expect(pass["barcodes"].first["message"]).to eq("abc123xyz")
    end

    it "defaults to eventTicket style" do
      pass = wallet.generate_pass(transaction)

      expect(pass).to have_key("eventTicket")
    end

    it "supports different pass styles" do
      %w[event_ticket boarding_pass coupon store_card generic].each do |style|
        pass = wallet.generate_pass(transaction, style: style)

        # eventTicket, boardingPass, coupon, storeCard, generic
        normalized = style.gsub(/_([a-z])/) { ::Regexp.last_match(1).upcase }
        expect(pass.keys).to include(normalized)
      end
    end

    it "includes event details in fields" do
      pass = wallet.generate_pass(transaction, {
        event_name: "Rock Concert",
        event_date: "2024-03-15T20:00:00+08:00",
        event_location: "Stadium",
        ticket_type: "VIP"
      })

      fields = pass["eventTicket"]

      expect(fields["primaryFields"].first["value"]).to eq("Rock Concert")
      expect(fields["auxiliaryFields"].find { |f| f["key"] == "ticketType" }["value"]).to eq("VIP")
    end

    it "includes seat info when provided" do
      pass = wallet.generate_pass(transaction, {
        seat_info: "A1",
        gate_info: "North Gate"
      })

      fields = pass["eventTicket"]["auxiliaryFields"]
      seat_field = fields.find { |f| f["key"] == "seat" }
      gate_field = fields.find { |f| f["key"] == "gate" }

      expect(seat_field["value"]).to eq("A1")
      expect(gate_field["value"]).to eq("North Gate")
    end

    it "includes attendee in header" do
      pass = wallet.generate_pass(transaction)

      header = pass["eventTicket"]["headerFields"]
      attendee = header.find { |f| f["key"] == "attendee" }

      expect(attendee["value"]).to eq("John Doe")
    end

    it "includes back fields with details" do
      pass = wallet.generate_pass(transaction)

      back_fields = pass["eventTicket"]["backFields"]

      expect(back_fields.find { |f| f["key"] == "reference" }["value"]).to eq("abc123xyz")
      expect(back_fields.find { |f| f["key"] == "email" }["value"]).to eq("john@example.com")
      expect(back_fields.find { |f| f["key"] == "amount" }["value"]).to include("150.00")
    end

    it "sets colors" do
      pass = wallet.generate_pass(transaction, {
        background_color: "rgb(255, 0, 0)",
        foreground_color: "rgb(255, 255, 255)",
        label_color: "rgb(200, 200, 200)"
      })

      expect(pass["backgroundColor"]).to eq("rgb(255, 0, 0)")
      expect(pass["foregroundColor"]).to eq("rgb(255, 255, 255)")
      expect(pass["labelColor"]).to eq("rgb(200, 200, 200)")
    end

    it "includes relevant date when event date provided" do
      pass = wallet.generate_pass(transaction, {
        event_date: "2024-03-15T20:00:00+08:00"
      })

      expect(pass["relevantDate"]).to eq("2024-03-15T20:00:00+08:00")
    end

    it "includes locations for geofencing" do
      pass = wallet.generate_pass(transaction, {
        locations: [
          { latitude: 3.1579, longitude: 101.7116, relevant_text: "Near venue" }
        ]
      })

      expect(pass["locations"]).to be_an(Array)
      expect(pass["locations"].first["latitude"]).to eq(3.1579)
    end

    it "supports voided passes" do
      pass = wallet.generate_pass(transaction, voided: true)

      expect(pass["voided"]).to be true
    end
  end

  describe "#to_hash" do
    it "returns pass data as hash" do
      result = wallet.to_hash(transaction, event_name: "Test Event")

      expect(result).to be_a(Hash)
      expect(result["description"]).to eq("Test Event")
    end
  end

  describe "#can_sign?" do
    it "returns false without certificates" do
      expect(wallet.can_sign?).to be false
    end

    it "returns false with non-existent certificate paths" do
      wallet_with_certs = described_class.new(
        certificate_path: "/nonexistent/path.p12",
        wwdr_certificate_path: "/nonexistent/wwdr.pem"
      )

      expect(wallet_with_certs.can_sign?).to be false
    end
  end

  describe "#generate_pkpass" do
    it "generates a .pkpass file" do
      output_path = "/tmp/test_pass_#{Time.now.to_i}"

      begin
        result = wallet.generate_pkpass(transaction, output_path, {
          event_name: "Test Event"
        })

        expect(result).to eq("#{output_path}.pkpass")
        expect(File.exist?(result)).to be true
      ensure
        File.delete("#{output_path}.pkpass") if File.exist?("#{output_path}.pkpass")
      end
    end
  end

  describe "edge cases" do
    it "handles transaction with missing bill code" do
      minimal = {}
      pass = wallet.generate_pass(minimal)

      expect(pass["barcodes"].first["message"]).to eq("UNKNOWN")
    end

    it "handles different bill code key formats" do
      [
        { "BillCode" => "code1" },
        { "billCode" => "code2" },
        { "bill_code" => "code3" }
      ].each do |txn|
        pass = wallet.generate_pass(txn)
        expect(pass["barcodes"].first["message"]).not_to eq("UNKNOWN")
      end
    end
  end
end
