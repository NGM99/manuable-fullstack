namespace :rates do
  desc "Import phase-one CSV files without duplicating completed imports"
  task import: :environment do
    RateImporter.new.call.each do |report|
      puts "#{report.file_name}: #{report.status} #{report.summary.to_json}"
    end
  end
end
