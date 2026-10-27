require "rails_helper"
require "tempfile"

RSpec.describe "Phase 2 maintenance", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:revision_path) { Rails.root.join("db/data/tarifas_dhl_v2.csv") }
  let(:input) do
    { email: "fase2@example.test", origin_postal_code: "06600",
      destination_postal_code: "06600", weight_kg: "2.5" }
  end
  let(:dimensions) { { length_cm: "40", width_cm: "30", height_cm: "20" } }
  let(:point) { { latitude: 19.4, longitude: -99.1 } }
  let(:authorization) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV.fetch("ADMIN_USER"), ENV.fetch("ADMIN_PASSWORD")) }
  end

  around { |example| travel_to(Time.zone.local(2026, 11, 20, 12)) { example.run } }
  before do
    RateImporter.new.call
    BillingRules.load!
  end

  def revise
    RateRevisionImporter.new.call(revision_path)
  end

  def temporary_csv(content)
    Tempfile.create(["revision", ".csv"]) do |file|
      file.write(content)
      file.flush
      yield file.path
    end
  end

  it "activates 24 new DHL rates only on December 1, preserving all other carriers" do
    other_rates = Rate.joins(:carrier).where.not(carriers: { name: "DHL" }).order(:id).map(&:attributes)
    old_dhl = Rate.joins(:carrier).where(carriers: { name: "DHL" }).pluck(:id, :price_mxn)
    expect(revise.status).to eq("completed")
    expect(Rate.current(Date.new(2026, 11, 30)).where(carrier: Carrier.find_by!(name: "DHL")).count).to eq(old_dhl.size)
    expect(Rate.current(Date.new(2026, 12, 1)).where(carrier: Carrier.find_by!(name: "DHL")).count).to eq(24)
    expect(Rate.where(id: old_dhl.map(&:first)).order(:id).pluck(:id, :price_mxn)).to eq(old_dhl.sort)
    expect(Rate.joins(:carrier).where.not(carriers: { name: "DHL" }).order(:id).map(&:attributes)).to eq(other_rates)
    expect(Rate.where(id: old_dhl.map(&:first)).pluck(:effective_until).uniq).to eq([Date.new(2026, 12, 1)])
  end

  it "does not duplicate an already completed revision" do
    revise
    counts = [Rate.count, RateImport.count]
    revise
    expect([Rate.count, RateImport.count]).to eq(counts)
  end

  it "rolls back the entire revision when any row is invalid" do
    original = Rate.order(:id).map(&:attributes)
    rows = CSV.read(revision_path, headers: true)
    rows[-1]["precio_mxn"] = "0"
    temporary_csv(rows.to_csv) do |path|
      report = RateRevisionImporter.new.call(path)
      expect(report.status).to eq("failed")
      expect(report.rows.size).to eq(24)
    end
    expect(Rate.order(:id).map(&:attributes)).to eq(original)
  end

  it "accepts the next tariff book from a CSV without changing application code" do
    revise
    content = "paqueteria,zona,peso_min_kg,peso_max_kg,precio_mxn,dias_entrega,vigencia_desde\n" \
      "DHL,1,0,30,800.00,2,2027-01-01\n"
    temporary_csv(content) { |path| expect(RateRevisionImporter.new.call(path).status).to eq("completed") }
    carrier = Carrier.find_by!(name: "DHL")
    expect(Rate.current(Date.new(2026, 12, 31)).where(carrier: carrier).count).to eq(24)
    expect(Rate.current(Date.new(2027, 1, 1)).where(carrier: carrier).pluck(:price_mxn)).to eq([BigDecimal("800")])
  end

  it "uses real weight before December and per-carrier volumetric weight from December 1" do
    revise
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return(point)
    travel_to(Time.zone.local(2026, 11, 30, 23, 59, 59))
    post "/api/v1/quotes", params: input.merge(dimensions), as: :json
    expect(response).to have_http_status(:created)
    expect(Quote.last.options.all? { |option| option["billable_weight_kg"] == "2.5" }).to be(true)
    travel_to(Time.zone.local(2026, 12, 1))
    post "/api/v1/quotes", params: input.merge(dimensions), as: :json
    expect(response).to have_http_status(:created)
    options = Quote.last.options.index_by { |option| option["carrier_name"] }
    expect(options.fetch("DHL")).to include("billable_weight_kg" => "4.8", "price_mxn" => "481.78")
    expect(options.fetch("FedEx")).to include("billable_weight_kg" => "4.8", "price_mxn" => "472.5")
    expect(options.fetch("Estafeta")).to include("billable_weight_kg" => "2.5", "price_mxn" => "198.55")
  end

  it "never bills less than the real weight and rounds volumetric grams upward" do
    carrier = Carrier.find_by!(name: "DHL")
    quote = Quote.new(input.merge(dimensions, weight_kg: "7"))
    date = Date.new(2026, 12, 1)
    expect(BillableWeight.call(carrier, quote, date: date).fetch(:weight)).to eq(BigDecimal("7"))
    quote.assign_attributes(length_cm: "100.001", width_cm: "100", height_cm: "5")
    expect(BillableWeight.call(carrier, quote, date: date).fetch(:weight)).to eq(BigDecimal("10.001"))
  end

  it "allows activating Estafeta volumetric billing through configuration" do
    carrier = Carrier.find_by!(name: "Estafeta")
    temporary_csv({ carrier.external_id => [
      { effective_from: "2027-01-01", method: "volumetric", divisor: 5000 }
    ] }.to_json) { |path| BillingRules.load!(path) }
    quote = Quote.new(input.merge(dimensions))
    carrier.reload
    expect(BillableWeight.call(carrier, quote, date: Date.new(2026, 12, 31))[:weight]).to eq(BigDecimal("2.5"))
    expect(BillableWeight.call(carrier, quote, date: Date.new(2027, 1, 1))[:weight]).to eq(BigDecimal("4.8"))
  end

  it "keeps real-weight options and explains missing dimensions without undercharging DHL or FedEx" do
    revise
    travel_to(Time.zone.local(2026, 12, 1))
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return(point)
    post "/api/v1/quotes", params: input, as: :json
    expect(Quote.last.options.pluck("carrier_name")).to eq(["Estafeta"])
    expect(response.parsed_body["quote"]["warnings"].join).to include("DHL", "FedEx")
  end

  it "returns a clear result when all usable rates need dimensions" do
    revise
    travel_to(Time.zone.local(2026, 12, 1))
    lookup = ->(cp) { cp == "06600" ? point : { latitude: 21.4, longitude: -99.1 } }
    result = QuoteCalculator.new(lookup: lookup).call(Quote.new(input.merge(destination_postal_code: "64000", weight_kg: "1")))
    expect(result[:status]).to eq("dimensions_required")
    expect(result[:options]).to eq([])
  end

  it "rejects partial or invalid dimensions before consulting the postal service" do
    expect_any_instance_of(PostalCodeLookup).not_to receive(:call)
    [{ length_cm: "20" }, dimensions.merge(height_cm: "-1"), dimensions.merge(width_cm: "1.0001")].each do |size|
      post "/api/v1/quotes", params: input.merge(size), as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(Quote.count).to eq(0)
  end

  it "preserves displayed prices across a revision and marks the exact 30-day boundary" do
    allow_any_instance_of(PostalCodeLookup).to receive(:call).and_return(point)
    post "/api/v1/quotes", params: input.merge(weight_kg: "7"), as: :json
    quote = Quote.last
    original = quote.options.deep_dup
    revise
    expect(quote.reload.options).to eq(original)
    expect(quote.price_honored?(at: quote.valid_until - 1.second)).to be(true)
    expect(quote.price_honored?(at: quote.valid_until)).to be(false)
    get "/api/v1/admin/quotes/#{quote.id}", headers: authorization
    expect(response.parsed_body["quote"]["options"]).to eq(original)
  end

  it "assigns validity and distinguishes future quotes from expired quotes" do
    quote = Quote.create!(input.merge(status: "quoted", options: [{ price_mxn: "198.55" }]))
    expect(quote.valid_until).to eq(quote.quoted_at + 30.days)
    expect(quote.public_data["price_status"]).to eq("valid")
    future = Quote.create!(input.merge(status: "quoted", quoted_at: Time.current + 1.day))
    expect(future.public_data["price_status"]).to eq("not_started")
  end

  it "imports all 40 manual quotes with their original amounts, dates and leading postal zeros" do
    expect_any_instance_of(PostalCodeLookup).not_to receive(:call)
    report = HistoricalQuoteImporter.new.call
    expect(report.summary).to include("total" => 40, "normalized" => 40, "rejected" => 0)
    expect(Quote.where(source: "manual").count).to eq(40)
    CSV.foreach(Rails.root.join("db/data/cotizaciones_historicas.csv"), headers: true) do |row|
      quote = Quote.find_by!(external_reference: row["cotizacion_id"])
      expect(BigDecimal(quote.options.first["price_mxn"])).to eq(BigDecimal(row["precio_cotizado"]))
      expect(quote.quoted_at.to_date.iso8601).to eq(row["fecha"])
      expect(quote.origin_postal_code).to eq(row["cp_origen"])
      expect(quote.zone).to eq(row["zona"].to_i)
      expect(quote.distance_km).to be_nil
      expect(quote.options.first["rate_id"]).to be_nil
      expect(quote.valid_until.to_date).to eq(Date.iso8601(row["fecha"]) + 30)
    end
    expect { HistoricalQuoteImporter.new.call }.not_to change(Quote, :count)
  end

  it "does not overwrite a historical price when its external identifier is imported again" do
    HistoricalQuoteImporter.new.call
    first = Quote.find_by!(external_reference: "COT-0001")
    table = CSV.read(Rails.root.join("db/data/cotizaciones_historicas.csv"), headers: true)
    table[0]["precio_cotizado"] = "1.00"
    temporary_csv(table.to_csv) do |path|
      report = HistoricalQuoteImporter.new.call(path)
      expect(report.summary["rejected"]).to eq(40)
    end
    expect(first.reload.options.first["price_mxn"]).to eq("1514.24")
    expect(Quote.count).to eq(40)
  end

  it "trims postal spaces, reuses the lookup for identical codes and gives repeatable options" do
    lookup = instance_double(PostalCodeLookup)
    allow(PostalCodeLookup).to receive(:new).and_return(lookup)
    expect(lookup).to receive(:call).with("06600").twice.and_return(point)
    post "/api/v1/quotes", params: input.merge(origin_postal_code: "06600 "), as: :json
    expect(response).to have_http_status(:created)
    expect(Quote.last.origin_postal_code).to eq("06600")
    original = Quote.last.options
    post "/api/v1/quotes", params: input, as: :json
    expect(Quote.last.options).to eq(original)
  end

  it "rejects city names explicitly, without calling Zippopotam" do
    expect_any_instance_of(PostalCodeLookup).not_to receive(:call)
    post "/api/v1/quotes", params: input.merge(origin_postal_code: "Monterrey"), as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]).to have_key("origin_postal_code")
  end

  it "reports daily figures in Monterrey time, separates sources and protects access" do
    Quote.create!(input.merge(status: "quoted", options: [{ price_mxn: "198.55" }],
      quoted_at: Time.iso8601("2026-11-21T05:30:00Z")))
    Quote.create!(input.merge(status: "no_rates", quoted_at: Time.iso8601("2026-11-21T05:45:00Z")))
    Quote.create!(input.merge(status: "pending", quoted_at: Time.iso8601("2026-11-21T06:30:00Z")))
    Quote.create!(input.merge(source: "manual", status: "quoted", options: [{ price_mxn: "198.55" }],
      quoted_at: Time.iso8601("2026-11-21T05:30:00Z")))
    get "/api/v1/admin/stats"
    expect(response).to have_http_status(:unauthorized)
    get "/api/v1/admin/stats", headers: authorization
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["days"]).to include(
      { "date" => "2026-11-20", "source" => "web", "total" => 2, "without_options" => 1 },
      { "date" => "2026-11-20", "source" => "manual", "total" => 1, "without_options" => 0 },
      { "date" => "2026-11-21", "source" => "web", "total" => 1, "without_options" => 0 })
  end
end
