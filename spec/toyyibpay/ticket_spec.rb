# frozen_string_literal: true

require "spec_helper"

RSpec.describe ToyyibPay::Ticket do
  let(:transaction) do
    {
      "BillCode" => "abc123xyz",
      "billName" => "Concert Ticket",
      "billDescription" => "Live Music Concert",
      "billTo" => "John Doe",
      "billEmail" => "john@example.com",
      "billPhone" => "0123456789",
      "billAmount" => 15000,
      "billStatus" => "1",
      "billPaymentDate" => "2024-03-15 10:30:00"
    }
  end

  describe ".generate" do
    it "generates HTML ticket with default template" do
      html = described_class.generate(transaction)

      expect(html).to include("<!DOCTYPE html>")
      expect(html).to include("Concert Ticket")
      expect(html).to include("John Doe")
      expect(html).to include("TKT-")
    end

    it "includes event information when provided" do
      html = described_class.generate(transaction, {
        event_name: "Tech Conference 2024",
        event_date: "March 15, 2024",
        event_time: "9:00 AM",
        event_location: "KLCC Convention Center"
      })

      expect(html).to include("Tech Conference 2024")
      expect(html).to include("March 15, 2024")
      expect(html).to include("9:00 AM")
      expect(html).to include("KLCC Convention Center")
    end

    it "includes ticket type and seat info" do
      html = described_class.generate(transaction, {
        ticket_type: "VIP Pass",
        seat_info: "Section A, Row 5, Seat 12",
        gate_info: "Gate B"
      })

      expect(html).to include("VIP Pass")
      expect(html).to include("Section A, Row 5, Seat 12")
      expect(html).to include("Gate B")
    end

    it "formats amount correctly" do
      html = described_class.generate(transaction)

      expect(html).to include("MYR")
      expect(html).to include("150.00")
    end

    it "generates QR code section by default" do
      html = described_class.generate(transaction)

      expect(html).to include("qr-section")
      expect(html).to include("Scan this QR code")
    end

    it "excludes QR code when disabled" do
      html = described_class.generate(transaction, include_qr: false)

      expect(html).not_to include("qr-section")
    end

    it "includes custom fields" do
      html = described_class.generate(transaction, {
        custom_fields: {
          "Dietary" => "Vegetarian",
          "T-Shirt Size" => "Medium"
        }
      })

      expect(html).to include("Dietary")
      expect(html).to include("Vegetarian")
      expect(html).to include("T-Shirt Size")
      expect(html).to include("Medium")
    end

    it "supports dark theme" do
      html = described_class.generate(transaction, theme: :dark)

      expect(html).to include("background: #0f0f0f")
      expect(html).to include("background: #1a1a1a")
    end

    it "supports minimal theme" do
      html = described_class.generate(transaction, theme: :minimal)

      expect(html).to include("border: 2px solid #000")
    end

    it "allows custom template" do
      custom_template = "<html><body>Custom: <%= event_name %></body></html>"
      html = described_class.generate(transaction, {
        template: custom_template,
        event_name: "My Event"
      })

      expect(html).to eq("<html><body>Custom: My Event</body></html>")
    end

    it "includes organizer information" do
      html = described_class.generate(transaction, {
        organizer_name: "Awesome Events Co."
      })

      expect(html).to include("Awesome Events Co.")
    end

    it "shows confirmed status for paid transactions" do
      html = described_class.generate(transaction)

      expect(html).to include("Confirmed")
      expect(html).to include("status-paid")
    end

    it "includes terms when provided" do
      html = described_class.generate(transaction, {
        terms: "No refunds after purchase."
      })

      expect(html).to include("No refunds after purchase.")
    end
  end

  describe ".generate_to_file" do
    it "writes HTML to a file" do
      filepath = "/tmp/test_ticket_#{Time.now.to_i}.html"

      begin
        result = described_class.generate_to_file(transaction, filepath)

        expect(result).to eq(filepath)
        expect(File.exist?(filepath)).to be true
        expect(File.read(filepath)).to include("Concert Ticket")
      ensure
        File.delete(filepath) if File.exist?(filepath)
      end
    end
  end

  describe ".generate_batch" do
    let(:transactions) do
      [
        { "BillCode" => "ticket1", "billName" => "Ticket 1", "billTo" => "Alice" },
        { "BillCode" => "ticket2", "billName" => "Ticket 2", "billTo" => "Bob" },
        { "BillCode" => "ticket3", "billName" => "Ticket 3", "billTo" => "Charlie" }
      ]
    end

    it "generates multiple tickets" do
      tickets = described_class.generate_batch(transactions)

      expect(tickets.length).to eq(3)
      expect(tickets[0]).to include("Alice")
      expect(tickets[1]).to include("Bob")
      expect(tickets[2]).to include("Charlie")
    end

    it "applies shared options to all tickets" do
      tickets = described_class.generate_batch(transactions, {
        event_name: "Shared Event",
        ticket_type: "General"
      })

      tickets.each do |ticket|
        expect(ticket).to include("Shared Event")
        expect(ticket).to include("General")
      end
    end
  end

  describe "edge cases" do
    it "handles transaction with missing fields" do
      minimal_transaction = { "BillCode" => "min123" }
      html = described_class.generate(minimal_transaction)

      expect(html).to include("TKT-")
      expect(html).to include("Guest")
      expect(html).to include("Entry Pass")
    end

    it "handles different bill code key formats" do
      transaction_variants = [
        { "BillCode" => "code1" },
        { "billCode" => "code2" },
        { "bill_code" => "code3" }
      ]

      transaction_variants.each do |txn|
        html = described_class.generate(txn)
        expect(html).to include("TKT-")
      end
    end

    it "sanitizes HTML in user input" do
      malicious_transaction = transaction.merge({
        "billTo" => "<script>alert('xss')</script>John"
      })

      html = described_class.generate(malicious_transaction)

      expect(html).not_to include("<script>alert")
    end
  end
end
