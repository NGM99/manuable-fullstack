require "rails_helper"

RSpec.describe "Invalid quote input types", type: :request do
  it "returns validation errors for numeric emails and shortened numeric postal codes instead of crashing" do
    expect_any_instance_of(PostalCodeLookup).not_to receive(:call)
    input = { email: "persona@example.test", origin_postal_code: "06600",
      destination_postal_code: "64000", weight_kg: "1" }
    [input.merge(email: 123), input.merge(origin_postal_code: 6600)].each do |params|
      post "/api/v1/quotes", params: params, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to have_key("errors")
    end
    expect(Quote.count).to eq(0)
  end

  it "rejects incomplete Basic credentials without raising a server error" do
    get "/api/v1/admin/leads", headers: { "Authorization" => "Basic " + ["comercial"].pack("m0") }
    expect(response).to have_http_status(:unauthorized)
  end
end
