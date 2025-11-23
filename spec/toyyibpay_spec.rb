# frozen_string_literal: true

RSpec.describe ToyyibPay do
  it "has a version number" do
    expect(ToyyibPay::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields configuration" do
      expect { |b| ToyyibPay.configure(&b) }.to yield_with_args(ToyyibPay.configuration)
    end

    it "sets configuration values" do
      ToyyibPay.configure do |config|
        config.api_key = "test-key"
        config.sandbox = true
      end

      expect(ToyyibPay.configuration.api_key).to eq("test-key")
      expect(ToyyibPay.configuration.sandbox).to be true
    end
  end

  describe ".reset_configuration!" do
    it "resets configuration to defaults" do
      ToyyibPay.configure do |config|
        config.api_key = "test-key"
        config.sandbox = true
      end

      ToyyibPay.reset_configuration!

      expect(ToyyibPay.configuration.api_key).to be_nil
      expect(ToyyibPay.configuration.sandbox).to be false
    end
  end

  describe "configuration delegation" do
    it "delegates api_key getter" do
      ToyyibPay.configuration.api_key = "test-key"
      expect(ToyyibPay.api_key).to eq("test-key")
    end

    it "delegates api_key setter" do
      ToyyibPay.api_key = "test-key"
      expect(ToyyibPay.configuration.api_key).to eq("test-key")
    end
  end

  describe ".client" do
    before { configure_toyyibpay }

    it "returns a default client" do
      expect(ToyyibPay.client).to be_a(ToyyibPay::Client)
    end
  end

  describe "resource shortcuts" do
    before { configure_toyyibpay }

    it "provides banks shortcut" do
      expect(ToyyibPay.banks).to be_a(ToyyibPay::Resources::Bank)
    end

    it "provides packages shortcut" do
      expect(ToyyibPay.packages).to be_a(ToyyibPay::Resources::Package)
    end

    it "provides categories shortcut" do
      expect(ToyyibPay.categories).to be_a(ToyyibPay::Resources::Category)
    end

    it "provides bills shortcut" do
      expect(ToyyibPay.bills).to be_a(ToyyibPay::Resources::Bill)
    end

    it "provides settlements shortcut" do
      expect(ToyyibPay.settlements).to be_a(ToyyibPay::Resources::Settlement)
    end

    it "provides users shortcut" do
      expect(ToyyibPay.users).to be_a(ToyyibPay::Resources::User)
    end
  end
end
