# frozen_string_literal: true

RSpec.describe ToyyibPay::Resources::Bank do
  let(:client) { ToyyibPay::Client.new("test-key", sandbox: true) }
  let(:banks) { client.banks }

  describe "#all" do
    it "returns list of banks" do
      response = [{ "bankID" => "1", "bankName" => "Test Bank" }]
      stub_toyyibpay_request(:post, "/index.php/api/getBank", response_body: response)

      result = banks.all
      expect(result).to eq(response)
    end

    it "returns empty array when response is not an array" do
      stub_toyyibpay_request(:post, "/index.php/api/getBank", response_body: {})

      result = banks.all
      expect(result).to eq([])
    end
  end

  describe "#fpx" do
    it "returns list of FPX banks" do
      response = [{ "bankID" => "1", "bankName" => "Test FPX Bank" }]
      stub_toyyibpay_request(:post, "/index.php/api/getBankFPX", response_body: response)

      result = banks.fpx
      expect(result).to eq(response)
    end
  end
end
