# frozen_string_literal: true

RSpec.describe ToyyibPay::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.api_key).to be_nil
      expect(config.category_code).to be_nil
      expect(config.sandbox).to be false
      expect(config.api_base).to eq("https://toyyibpay.com")
      expect(config.sandbox_api_base).to eq("https://dev.toyyibpay.com")
      expect(config.open_timeout).to eq(30)
      expect(config.read_timeout).to eq(80)
      expect(config.write_timeout).to eq(30)
      expect(config.max_retries).to eq(2)
    end
  end

  describe "#effective_api_base" do
    it "returns production URL when sandbox is false" do
      config.sandbox = false
      expect(config.effective_api_base).to eq("https://toyyibpay.com")
    end

    it "returns sandbox URL when sandbox is true" do
      config.sandbox = true
      expect(config.effective_api_base).to eq("https://dev.toyyibpay.com")
    end
  end

  describe "#validate!" do
    it "raises error when api_key is nil" do
      config.api_key = nil
      expect { config.validate! }.to raise_error(ToyyibPay::ConfigurationError, "API key is required")
    end

    it "raises error when api_key is empty" do
      config.api_key = ""
      expect { config.validate! }.to raise_error(ToyyibPay::ConfigurationError, "API key is required")
    end

    it "does not raise error when api_key is set" do
      config.api_key = "test-key"
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#reset!" do
    it "resets to default values" do
      config.api_key = "test-key"
      config.sandbox = true
      config.reset!

      expect(config.api_key).to be_nil
      expect(config.sandbox).to be false
    end
  end
end
