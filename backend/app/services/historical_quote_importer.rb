require "csv"
require "digest"

class HistoricalQuoteImporter
  def call(path = Rails.root.join("db/data/cotizaciones_historicas.csv"))
    path = Pathname(path)
    identity = { file_name: path.basename.to_s, checksum: Digest::SHA256.file(path).hexdigest,
      rules_version: "history-1" }
    previous = RateImport.find_by(identity.merge(status: "completed"))
    return previous if previous
    table = CSV.read(path, headers: true, encoding: "bom|utf-8")
    required = %w[cotizacion_id fecha correo cp_origen cp_destino zona peso_kg paqueteria precio_cotizado]
    raise ArgumentError, "Archivo vacío o encabezados inválidos" if table.empty? || (required - table.headers.to_a).any?
    audit = []
    RateImport.transaction do
      report = RateImport.create!(identity)
      table.each.with_index(2) do |row, line|
        raw = row.to_h
        values = {}
        begin
          raise ArgumentError, "Número de columnas inválido" unless row.fields.length == table.headers.length
          reference = raw.fetch("cotizacion_id").to_s.strip
          raise ArgumentError, "Identificador vacío" if reference.empty?
          raise ArgumentError, "Fecha inválida" unless raw["fecha"].to_s.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
          date = Date.iso8601(raw.fetch("fecha"))
          raise ArgumentError, "Zona inválida" unless raw["zona"].to_s.match?(/\A[1-4]\z/)
          raise ArgumentError, "Precio inválido" unless raw["precio_cotizado"].to_s.match?(/\A[0-9]+(?:\.[0-9]{1,2})?\z/)
          price = BigDecimal(raw.fetch("precio_cotizado"))
          raise ArgumentError, "Precio inválido" unless price > 0 && price < 10_000_000_000
          carrier = Carrier.find_by!(name: raw.fetch("paqueteria").to_s.strip)
          values = { external_reference: reference, source: "manual", email: raw["correo"],
            origin_postal_code: raw["cp_origen"], destination_postal_code: raw["cp_destino"],
            zone: raw["zona"].to_i, weight_kg: raw["peso_kg"], status: "quoted",
            quoted_at: date.in_time_zone, valid_until: (date + 30).in_time_zone.end_of_day,
            options: [{ carrier_id: carrier.id, carrier_name: carrier.name, service_type: carrier.service_type,
              price_mxn: price.to_s("F"), currency: "MXN", delivery_days_min: nil, delivery_days_max: nil,
              rate_id: nil, billable_weight_kg: nil, billing_method: "unknown" }],
            metadata: { import_id: report.id, source_line: line, original_date_only: true } }
          raise ArgumentError, "Identificador histórico ya registrado; no se modifica su precio" if Quote.exists?(external_reference: reference)
          Quote.create!(values)
          audit << { line: line, original: raw, normalized: values.except(:metadata),
            status: "NORMALIZADO", reasons: ["Cotización manual conservada sin recalcular precio ni zona"] }
        rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
          audit << { line: line, original: raw, normalized: values,
            status: "RECHAZADO", reasons: [error.message] }
        end
      end
      rejected = audit.count { |row| row[:status] == "RECHAZADO" }
      report.update!(status: "completed", rows: audit,
        summary: { total: audit.size, normalized: audit.size - rejected, accepted: 0, rejected: rejected })
      report
    end
  rescue CSV::MalformedCSVError, ArgumentError => error
    RateImport.create!(identity.merge(status: "failed", rows: [],
      summary: { error: error.message }))
  end
end
