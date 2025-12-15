# frozen_string_literal: true

require "spec_helper"

RSpec.describe ToyyibPay::Wallet do
  let(:transaction) do
    {
      "BillCode" => "abc123xyz",
      "billName" => "Concert Ticket",
      "billTo" => "John Doe",
      "billEmail" => "john@example.com",
      "billAmount" => 15000
    }
  end

  describe ".apple" do
    it "creates an Apple Wallet generator" do
      apple = described_class.apple(pass_type_identifier: "pass.com.test")

      expect(apple).to be_a(ToyyibPay::Wallet::AppleWallet)
    end
  end

  describe ".google" do
    it "creates a Google Wallet generator" do
      google = described_class.google(issuer_id: "123456789")

      expect(google).to be_a(ToyyibPay::Wallet::GoogleWallet)
    end
  end

  describe ".generate_all" do
    it "generates passes for both platforms" do
      result = described_class.generate_all(
        transaction,
        { event_name: "Test Event" },
        {
          apple: { pass_type_identifier: "pass.com.test" },
          google: { issuer_id: "123456789" }
        }
      )

      expect(result).to have_key(:apple)
      expect(result).to have_key(:google)
      expect(result[:apple][:pass_data]).to be_a(Hash)
      expect(result[:google][:pass_data]).to be_a(Hash)
    end

    it "generates only Apple pass when Google not configured" do
      result = described_class.generate_all(
        transaction,
        { event_name: "Test Event" },
        {
          apple: { pass_type_identifier: "pass.com.test" }
        }
      )

      expect(result).to have_key(:apple)
      expect(result).not_to have_key(:google)
    end

    it "generates only Google pass when Apple not configured" do
      result = described_class.generate_all(
        transaction,
        { event_name: "Test Event" },
        {
          google: { issuer_id: "123456789" }
        }
      )

      expect(result).not_to have_key(:apple)
      expect(result).to have_key(:google)
    end

    it "includes signing capability status" do
      result = described_class.generate_all(
        transaction,
        {},
        {
          apple: { pass_type_identifier: "pass.com.test" }
        }
      )

      expect(result[:apple]).to have_key(:can_sign)
      expect(result[:apple][:can_sign]).to be false
    end
  end

  describe ".buttons_html" do
    it "returns empty string when no platforms configured" do
      html = described_class.buttons_html(transaction, {}, {})

      expect(html).to eq("")
    end

    it "includes Apple button when download URL provided" do
      html = described_class.buttons_html(
        transaction,
        {},
        { apple: { download_url: "https://example.com/pass.pkpass" } }
      )

      expect(html).to include("Add to Apple Wallet")
      expect(html).to include("https://example.com/pass.pkpass")
    end
  end
end
