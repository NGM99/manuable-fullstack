require "csv"
require "digest"

# A revision replaces the complete tariff book of ONE carrier from ONE date.
# The shared phase-one parser still validates money, weights, days and aliases.
class RateRevisionImporter < RateImporter
  def call(path)
    path = Pathname(path)
    identity = { file_name: path.basename.to_s, checksum: Digest::SHA256.file(path).hexdigest,
      rules_version: "revision-1" }
    previous = RateImport.find_by(identity.merge(status: "completed"))
    return previous if previous
    audit = []
    table = CSV.read(path, headers: true, encoding: "bom|utf-8")
    required = %w[paqueteria zona peso_min_kg peso_max_kg precio_mxn dias_entrega vigencia_desde]
    raise ArgumentError, "Archivo vacío o encabezados inválidos" if table.empty? || (required - table.headers).any?
    dates = table.map { |row| parse_date(row["vigencia_desde"]) }.uniq
    names = table.map { |row| ALIASES.fetch(key(row["paqueteria"]), key(row["paqueteria"])) }.uniq
    raise ArgumentError, "Cada revisión debe tener una paquetería y una fecha" unless dates.one? && names.one?
    date = dates.first
    RateImport.transaction do
      carrier = Carrier.all.find { |item| key(item.name) == names.first }
      raise ActiveRecord::RecordNotFound, "Paquetería fuera del catálogo" unless carrier
      carrier.lock!
      raise ArgumentError, "Paquetería inactiva" unless carrier.active?
      if carrier.rates.where("effective_from >= ?", date).exists?
        raise ArgumentError, "La revisión debe ser posterior a las versiones ya cargadas"
      end
      report = RateImport.create!(identity)
      carrier.rates.where("effective_from < ?", date)
        .where("effective_until IS NULL OR effective_until > ?", date).update_all(effective_until: date)
      table.each.with_index(2) do |row, line|
        original = row.to_h
        errors = []
        changes = []
        errors << "Número de columnas inválido" unless row.fields.length == table.headers.length
        raw = { "paqueteria" => original["paqueteria"], "zona" => original["zona"],
          "peso_min" => original["peso_min_kg"], "peso_max" => original["peso_max_kg"],
          "unidad" => "kg", "precio" => original["precio_mxn"],
          "dias_entrega" => original["dias_entrega"], "vigencia_desde" => original["vigencia_desde"] }
        values, record = rate_record(raw, errors, changes, report, line)
        errors.concat(record.errors.full_messages) if errors.empty? && !record.valid?
        record.save! if errors.empty?
        audit << { line: line, original: original, normalized: values,
          status: errors.any? ? "RECHAZADO" : changes.any? ? "NORMALIZADO" : "ACEPTADO",
          reasons: errors.presence || changes.presence || ["Datos válidos"] }
      end
      raise ArgumentError, "Revisión cancelada: hay filas inválidas; se conservan las tarifas anteriores" if audit.any? { |r| r[:status] == "RECHAZADO" }
      counts = audit.map { |r| r[:status] }.tally
      report.update!(status: "completed", rows: audit, summary: { total: audit.size,
        accepted: counts.fetch("ACEPTADO", 0), normalized: counts.fetch("NORMALIZADO", 0), rejected: 0 })
      report
    end
  rescue CSV::MalformedCSVError, ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    audit.each do |row|
      row[:status] = "RECHAZADO"
      row[:reasons] << "Lote completo cancelado: #{error.message}"
    end
    RateImport.create!(identity.merge(status: "failed", rows: audit,
      summary: { total: table&.size || 0, accepted: 0, normalized: 0,
        rejected: table&.size || 0, error: error.message }))
  end
end
