require "rails_helper"

RSpec.describe "Contact search and pagination", type: :request do
  let(:authorization) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV.fetch("ADMIN_USER"), ENV.fetch("ADMIN_PASSWORD")) }
  end

  def contact(email)
    Quote.create!(email: email, origin_postal_code: "06600", destination_postal_code: "64000",
      weight_kg: "1", status: "no_rates")
  end

  it "returns ten distinct contacts per page with all their quotes and an accurate next-page flag" do
    11.times { |index| contact(format("cliente%02d@example.test", index)) }
    contact("cliente00@example.test")
    get "/api/v1/admin/leads", headers: authorization
    first = response.parsed_body
    expect(first).to include("page" => 1, "per_page" => 10, "has_next" => true)
    expect(first["leads"].size).to eq(10)
    expect(first["leads"].first["quotes"].size).to eq(2)
    get "/api/v1/admin/leads", params: { page: 2 }, headers: authorization
    second = response.parsed_body
    expect(second).to include("page" => 2, "has_next" => false)
    expect(second["leads"].pluck("email")).to eq(["cliente10@example.test"])
    expect(first["leads"].pluck("email") & second["leads"].pluck("email")).to be_empty
  end

  it "filters email fragments case-insensitively before paginating and escapes SQL pattern characters" do
    10.times { |index| contact("otro#{index}@example.test") }
    contact("ventas@tienda.test")
    contact("ventas@tienda.test")
    contact("compras@tienda.test")
    contact("tag%_literal@example.test")
    get "/api/v1/admin/leads", params: { q: "  TIENDA.TEST  " }, headers: authorization
    body = response.parsed_body
    expect(body["leads"].pluck("email")).to eq(["compras@tienda.test", "ventas@tienda.test"])
    expect(body["leads"].last["quotes"].size).to eq(2)
    expect(body["has_next"]).to be(false)
    get "/api/v1/admin/leads", params: { q: "%_" }, headers: authorization
    expect(response.parsed_body["leads"].pluck("email")).to eq(["tag%_literal@example.test"])
    get "/api/v1/admin/leads", params: { q: "' OR 1=1 --" }, headers: authorization
    expect(response.parsed_body["leads"]).to eq([])
    expect(response.parsed_body["has_next"]).to be(false)
  end
end
