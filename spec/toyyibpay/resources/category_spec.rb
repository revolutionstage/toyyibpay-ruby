# frozen_string_literal: true

RSpec.describe ToyyibPay::Resources::Category do
  let(:client) { ToyyibPay::Client.new("test-key", sandbox: true) }
  let(:categories) { client.categories }

  describe "#create" do
    it "creates a category with valid params" do
      response = [{ "CategoryCode" => "cat123" }]
      stub_toyyibpay_request(:post, "/index.php/api/createCategory", response_body: response)

      result = categories.create(catname: "Test Category", catdescription: "Test Description")
      expect(result).to eq(response)
    end

    it "raises error when catname is missing" do
      expect { categories.create(catdescription: "Test") }.to raise_error(ArgumentError, "catname is required")
    end

    it "raises error when catdescription is missing" do
      expect { categories.create(catname: "Test") }.to raise_error(ArgumentError, "catdescription is required")
    end
  end

  describe "#retrieve" do
    it "retrieves category details" do
      response = { "catname" => "Test Category" }
      stub_toyyibpay_request(:post, "/index.php/api/getCategoryDetails", response_body: response)

      result = categories.retrieve("cat123")
      expect(result).to eq(response)
    end

    it "uses client category_code if not provided" do
      client.config.category_code = "default-cat"
      response = { "catname" => "Test Category" }
      stub_toyyibpay_request(:post, "/index.php/api/getCategoryDetails", response_body: response)

      result = categories.retrieve
      expect(result).to eq(response)
    end

    it "raises error when category_code is not available" do
      expect { categories.retrieve }.to raise_error(ArgumentError, "category_code is required")
    end
  end
end
