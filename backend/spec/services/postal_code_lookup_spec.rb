require "rails_helper"

RSpec.describe PostalCodeLookup do
  subject(:lookup) { described_class.new.call("06600") }

  let(:http) { instance_double(Net::HTTP) }
  let(:response) { Net::HTTPOK.new("1.1", "200", "OK") }
  let(:body) do
    { places: [
      { latitude: "19.4", longitude: "-99.2" },
      { latitude: "19.6", longitude: "-99.0" }
    ] }.to_json
  end

  before do
    # Replace the HTTP boundary: no socket or public service is used.
    allow(Net::HTTP).to receive(:start)
      .with("api.zippopotam.us", 443, use_ssl: true, open_timeout: 2, read_timeout: 3)
      .and_yield(http)
    allow(http).to receive(:get).with("/mx/06600").and_return(response)
    allow(response).to receive(:body).and_return(body)
  end

  it "parses the postal response and averages the coordinates of its places" do
    expect(lookup).to eq(latitude: 19.5, longitude: -99.1)
  end

  context "when the postal code does not exist" do
    let(:response) { Net::HTTPNotFound.new("1.1", "404", "Not Found") }

    it "distinguishes a missing code from a service failure" do
      expect { lookup }.to raise_error(described_class::NotFound, "06600")
    end
  end

  context "when the provider returns an error" do
    let(:response) { Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable") }

    it "reports an unavailable service" do
      expect { lookup }.to raise_error(described_class::Unavailable)
    end
  end

  it "handles a read timeout without exposing network details" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout, "private network details")
    expect { lookup }.to raise_error(described_class::Unavailable, "Postal lookup unavailable")
  end

  context "when the response is not valid JSON" do
    let(:body) { "invalid JSON" }

    it "reports a service failure instead of calculating with invented coordinates" do
      expect { lookup }.to raise_error(described_class::Unavailable)
    end
  end

  [{}, { places: [] }].each do |payload|
    context "when places are missing or empty: #{payload}" do
      let(:body) { payload.to_json }

      it "refuses to use an incomplete response" do
        expect { lookup }.to raise_error(described_class::Unavailable)
      end
    end
  end

  context "when coordinates fall outside the geographic limits" do
    let(:body) { { places: [{ latitude: "91", longitude: "-99" }] }.to_json }

    it "rejects the coordinates" do
      expect { lookup }.to raise_error(described_class::Unavailable)
    end
  end
end
