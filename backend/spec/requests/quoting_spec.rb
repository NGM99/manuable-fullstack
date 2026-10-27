require "rails_helper"

RSpec.describe "Phase 1 quoting", type: :request do
  let(:input) do
    { email: " Cliente@example.test ", origin_postal_code: "06600",
      destination_postal_code: "06600", weight_kg: "2.5" }
  end
  let(:authorization) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV.fetch("ADMIN_USER"), ENV.fetch("ADMIN_PASSWORD")) }
  end

  it "imports the supplied CSV once and retains every original row and rejection reason" do
    importer = RateImporter.new
    importer.call
    expect { importer.call }.not_to change(RateImport, :count)
    expect(Rate.count).to eq(25)
    report = RateImport.find_by!(file_name: "tarifas.csv")
    expect(report.rows.size).to eq(108)
    expect(report.summary).to include("normalized" => 25, "rejected" => 83)
    expect(report.rows.all? { |row| row["original"].any? && row["reasons"].any? }).to be(true)
    expect(report.rows.find { |row| row["line"] == 40 }["status"]).to eq("RECHAZADO")
  end

  it "uses the documented distance boundaries and Haversine calculation" do
    expect([100, 100.001, 500, 500.001, 1000, 1000.001].map { |km| QuoteCalculator.zone(km) })
      .to eq([1, 2, 2, 3, 3, 4])
    origin = { latitude: 0, longitude: 0 }
    expect(QuoteCalculator.distance(origin, { latitude: 0, longitude: 1 })).to be_within(0.01).of(111.195)
  end

  it "selects the upper weight boundary and excludes the lower boundary" do
    RateImporter.new.call
    rate = Rate.current.find_by!(zone: 1, weight_max_kg: 3, price_mxn: "198.55")
    lookup = ->(_) { { latitude: 19.4, longitude: -99.1 } }
    calculate = ->(weight) { QuoteCalculator.new(lookup: lookup).call(Quote.new(input.merge(weight_kg: weight))) }
    expect(calculate.call("3")[:options].pluck(:rate_id)).to include(rate.id)
    expect(calculate.call("1")[:options].pluck(:rate_id)).not_to include(rate.id)
  end

  it "captures normalized contacts, protects history and never exposes email publicly" do
    RateImporter.new.call
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return({ latitude: 19.4, longitude: -99.1 })
    post "/api/v1/quotes", params: input, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body["quote"]).not_to have_key("email")
    quote = Quote.last
    expect(quote.email).to eq("cliente@example.test")
    expect(quote.status).to eq("quoted")
    snapshot = quote.options.deep_dup
    Rate.find(snapshot.first.fetch("rate_id")).update!(price_mxn: "999.99")
    get "/api/v1/admin/quotes/#{quote.id}", headers: authorization
    expect(response.parsed_body.fetch("quote").fetch("options")).to eq(snapshot)
    get "/api/v1/admin/leads", headers: authorization
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("leads").first.fetch("email")).to eq(quote.email)
  end

  it "rejects malformed fields without calling the external service" do
    expect_any_instance_of(PostalCodeLookup).not_to receive(:call)
    post "/api/v1/quotes", params: input.merge(origin_postal_code: "6600", weight_kg: "0"), as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Quote.count).to eq(0)
  end

  it "keeps the contact and returns an actionable response when the external service fails" do
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_raise(PostalCodeLookup::Unavailable)
    post "/api/v1/quotes", params: input, as: :json
    expect(response).to have_http_status(:service_unavailable)
    expect(Quote.last.status).to eq("external_service_unavailable")
    expect(response.parsed_body["quote"]["options"]).to eq([])
  end

  it "keeps requests with missing postal codes and no rates, without creating prices" do
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_raise(PostalCodeLookup::NotFound, "06600")
    post "/api/v1/quotes", params: input, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Quote.last.status).to eq("postal_code_not_found")
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return({ latitude: 19.4, longitude: -99.1 })
    post "/api/v1/quotes", params: input, as: :json
    expect(response).to have_http_status(:created)
    expect(Quote.last.status).to eq("no_rates")
    expect(Quote.last.options).to eq([])
  end

  it "requires authentication on every internal endpoint" do
    %w[leads imports imports/1 quotes/1].each do |path|
      get "/api/v1/admin/#{path}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "keeps the contact without options when valid rates do not cover the requested weight" do
    RateImporter.new.call
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return({ latitude: 19.4, longitude: -99.1 })
    post "/api/v1/quotes", params: input.merge(weight_kg: "31"), as: :json
    expect(response).to have_http_status(:created)
    expect(Quote.last.status).to eq("weight_out_of_range")
    expect(Quote.last.email).to eq("cliente@example.test")
    expect(response.parsed_body.fetch("quote").fetch("options")).to eq([])
  end

  it "refuses incorrect credentials on every internal endpoint" do
    headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV.fetch("ADMIN_USER"), "incorrect-password") }
    %w[leads imports imports/1 quotes/1].each do |path|
      get "/api/v1/admin/#{path}", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
