namespace :rates do
  desc "Import phase-one CSV files without duplicating completed imports"
  task import: :environment do
    reports = RateImporter.new.call
    reports.each do |report|
      puts "#{report.file_name}: #{report.status} #{report.summary.to_json}"
    end
    abort("Hay archivos CSV inválidos; revisa los reportes de importación") if reports.any? { |report| report.status == "failed" }
  end

  desc "Replace a carrier's tariff book from its CSV effective date: rates:revise[path]"
  task :revise, [:path] => :environment do |_, args|
    raise ArgumentError, "Indica la ruta del CSV" unless args[:path]
    report = RateRevisionImporter.new.call(args[:path])
    puts "#{report.file_name}: #{report.status} #{report.summary.to_json}"
    abort("No se aplicó la revisión") unless report.status == "completed"
  end

  desc "Load carrier billing rules from JSON: rates:rules[path]"
  task :rules, [:path] => :environment do |_, args|
    BillingRules.load!(args[:path] || Rails.root.join("db/data/reglas_cobro.json"))
  end

  desc "Load bundled phase-two configuration and tariff revisions"
  task phase_two: :environment do
    BillingRules.load!
    report = RateRevisionImporter.new.call(Rails.root.join("db/data/tarifas_dhl_v2.csv"))
    puts "#{report.file_name}: #{report.status} #{report.summary.to_json}"
    abort("No se aplicó la revisión") unless report.status == "completed"
  end
end
