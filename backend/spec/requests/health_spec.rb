require "rails_helper"
RSpec.describe "Service health", type: :request do
  it "reports that Rails has booted" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end
  it "reports readiness after querying PostgreSQL" do
    get "/api/v1/health"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("status" => "ok")
  end
  it "returns a generic unavailable response when the database fails" do
    allow(ActiveRecord::Base).to receive(:connection)
      .and_raise(ActiveRecord::ConnectionNotEstablished, "private database details")
    get "/api/v1/health"
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("status" => "unavailable")
    expect(response.body).not_to include("private database details")
  end
end
