require "rails_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RateImporter do
  def import_rates(content)
    Dir.mktmpdir do |directory|
      FileUtils.cp(Rails.root.join("db/data/paqueterias.csv"), directory)
      File.write(File.join(directory, "tarifas.csv"), content)
      yield described_class.new(directory: directory).call.last
    end
  end

  it "records empty and malformed CSV files as failed imports without publishing rates" do
    ["", "paqueteria,zona\n\"sin cierre"].each do |content|
      import_rates(content) do |report|
        expect(report.status).to eq("failed")
        expect(report.summary.fetch("error")).to be_present
      end
    end
    expect(Rate.count).to eq(0)
  end

  it "rejects delivery times that exceed the database capacity without losing the audit" do
    csv = "paqueteria,zona,peso_min,peso_max,unidad,precio,dias_entrega,vigencia_desde\n" \
      "DHL,1,0,1,kg,100.00,2147483648,2026-01-01\n"
    import_rates(csv) do |report|
      expect(report.status).to eq("completed")
      expect(report.summary["rejected"]).to eq(1)
      expect(report.rows.first["reasons"].join).to include("Plazo")
      expect(report.rows.first["original"]["dias_entrega"]).to eq("2147483648")
    end
    expect(Rate.count).to eq(0)
  end
end
