# frozen_string_literal: true

RSpec.describe ToyyibPay::Client do
  describe "#initialize" do
    it "accepts api_key as first argument" do
      client = described_class.new("test-key")
      expect(client.config.api_key).to eq("test-key")
    end

    it "accepts options hash" do
      client = described_class.new("test-key", sandbox: true, category_code: "cat123")
      expect(client.config.sandbox).to be true
      expect(client.config.category_code).to eq("cat123")
    end

    it "uses global api_key if not provided" do
      ToyyibPay.api_key = "global-key"
      client = described_class.new
      expect(client.config.api_key).to eq("global-key")
    end
  end

  describe "#use_sandbox!" do
    it "enables sandbox mode" do
      client = described_class.new("test-key")
      expect(client.sandbox?).to be false

      client.use_sandbox!
      expect(client.sandbox?).to be true
    end

    it "returns self for chaining" do
      client = described_class.new("test-key")
      expect(client.use_sandbox!).to eq(client)
    end
  end

  describe "#use_production!" do
    it "disables sandbox mode" do
      client = described_class.new("test-key", sandbox: true)
      expect(client.sandbox?).to be true

      client.use_production!
      expect(client.sandbox?).to be false
    end
  end

  describe "resource accessors" do
    let(:client) { described_class.new("test-key") }

    it "provides banks resource" do
      expect(client.banks).to be_a(ToyyibPay::Resources::Bank)
    end

    it "provides packages resource" do
      expect(client.packages).to be_a(ToyyibPay::Resources::Package)
    end

    it "provides categories resource" do
      expect(client.categories).to be_a(ToyyibPay::Resources::Category)
    end

    it "provides bills resource" do
      expect(client.bills).to be_a(ToyyibPay::Resources::Bill)
    end

    it "provides settlements resource" do
      expect(client.settlements).to be_a(ToyyibPay::Resources::Settlement)
    end

    it "provides users resource" do
      expect(client.users).to be_a(ToyyibPay::Resources::User)
    end

    it "caches resource instances" do
      expect(client.bills).to be(client.bills)
    end
  end
end
