namespace :quotes do
  desc "Import historical quotes without recalculating prices: quotes:import_history[path]"
  task :import_history, [:path] => :environment do |_, args|
    report = HistoricalQuoteImporter.new.call(args[:path] || Rails.root.join("db/data/cotizaciones_historicas.csv"))
    puts "#{report.file_name}: #{report.status} #{report.summary.to_json}"
    abort("No se pudo leer el histórico") unless report.status == "completed"
  end
end
