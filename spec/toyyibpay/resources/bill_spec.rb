# frozen_string_literal: true

RSpec.describe ToyyibPay::Resources::Bill do
  let(:client) { ToyyibPay::Client.new("test-key", sandbox: true) }
  let(:bills) { client.bills }

  describe "#create" do
    let(:params) do
      {
        billName: "Test Bill",
        billDescription: "Test Description",
        billPriceSetting: "0",
        billPayorInfo: "1",
        billAmount: "10000"
      }
    end

    it "creates a bill with valid params" do
      response = [{ "BillCode" => "abc123" }]
      stub_toyyibpay_request(:post, "/index.php/api/createBill", response_body: response)

      result = bills.create(params)
      expect(result).to eq(response)
    end

    it "raises error when billName is missing" do
      params.delete(:billName)
      expect { bills.create(params) }.to raise_error(ArgumentError, "billName is required")
    end

    it "raises error when billDescription is missing" do
      params.delete(:billDescription)
      expect { bills.create(params) }.to raise_error(ArgumentError, "billDescription is required")
    end

    it "raises error when billPriceSetting is missing" do
      params.delete(:billPriceSetting)
      expect { bills.create(params) }.to raise_error(ArgumentError, "billPriceSetting is required")
    end

    it "raises error when billAmount is missing for fixed price" do
      params.delete(:billAmount)
      expect { bills.create(params) }.to raise_error(ArgumentError, /billAmount is required/)
    end
  end

  describe "#transactions" do
    it "retrieves bill transactions" do
      response = [{ "billpaymentStatus" => "1" }]
      stub_toyyibpay_request(:post, "/index.php/api/getBillTransactions", response_body: response)

      result = bills.transactions("abc123")
      expect(result).to eq(response)
    end

    it "raises error when bill_code is nil" do
      expect { bills.transactions(nil) }.to raise_error(ArgumentError, "bill_code is required")
    end

    it "raises error when bill_code is empty" do
      expect { bills.transactions("") }.to raise_error(ArgumentError, "bill_code is required")
    end
  end

  describe "#payment_url" do
    it "generates correct payment URL" do
      url = bills.payment_url("abc123")
      expect(url).to eq("https://dev.toyyibpay.com/abc123")
    end

    it "raises error when bill_code is nil" do
      expect { bills.payment_url(nil) }.to raise_error(ArgumentError, "bill_code is required")
    end
  end

  describe "#run" do
    let(:params) do
      {
        billCode: "abc123",
        billpayorEmail: "test@example.com",
        billpayorName: "John Doe",
        billpayorPhone: "0123456789"
      }
    end

    it "runs a bill with valid params" do
      response = { "status" => "success" }
      stub_toyyibpay_request(:post, "/index.php/api/runBill", response_body: response)

      result = bills.run(params)
      expect(result).to eq(response)
    end

    it "raises error when required params are missing" do
      expect { bills.run({}) }.to raise_error(ArgumentError, "billCode is required")
    end
  end
end
