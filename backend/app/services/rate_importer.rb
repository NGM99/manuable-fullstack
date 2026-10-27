require "csv"
require "digest"
require "bigdecimal"

class RateImporter
  ALIASES = {
    "dhl express" => "dhl", "d.h.l." => "dhl", "estafeta mexicana" => "estafeta",
    "fed ex" => "fedex", "federal express" => "fedex", "red pack" => "redpack"
  }.freeze

  def initialize(directory: Rails.root.join("db/data"))
    @directory = Pathname(directory)
    review_file = @directory.join("revision_pendiente.json")
    @review = review_file.exist? ? JSON.parse(review_file.read) : {}
    @version = "1-" + Digest::SHA256.hexdigest(JSON.generate(@review))[0, 8]
  end

  def call
    [import_file("paqueterias.csv", :carriers), import_file("tarifas.csv", :rates)]
  end

  private

  def import_file(name, kind)
    path = @directory.join(name)
    identity = { file_name: name, checksum: Digest::SHA256.file(path).hexdigest, rules_version: @version }
    previous = RateImport.find_by(identity.merge(status: "completed"))
    return previous if previous
    table = CSV.read(path, headers: true, encoding: "bom|utf-8")
    required = kind == :carriers ? %w[carrier_id nombre tipo_servicio activo] :
      %w[paqueteria zona peso_min peso_max unidad precio dias_entrega vigencia_desde]
    raise ArgumentError, "Faltan columnas: #{(required - table.headers).join(', ')}" if (required - table.headers).any?
    audit = []
    seen = {}
    RateImport.transaction do
      report = RateImport.create!(identity)
      table.each.with_index(2) do |row, line|
        original = row.to_h
        fingerprint = Digest::SHA256.hexdigest(JSON.generate(original.transform_values(&:to_s)))
        errors = []
        changes = []
        errors << "Número de columnas inválido" if row.fields.length != table.headers.length
        errors << "Duplicada de la fila #{seen[fingerprint]}" if seen.key?(fingerprint)
        seen[fingerprint] ||= line
        errors << @review[fingerprint].fetch("reason") if kind == :rates && @review.key?(fingerprint)
        values, record = kind == :carriers ?
          carrier_record(original, errors, changes) : rate_record(original, errors, changes, report, line)
        if errors.empty?
          record.valid? ? record.save! : errors.concat(record.errors.full_messages)
        end
        status = errors.any? ? "RECHAZADO" : changes.any? ? "NORMALIZADO" : "ACEPTADO"
        reasons = errors.any? ? errors : changes.presence || ["Datos válidos"]
        reasons += ["Plazo de entrega no informado"] if kind == :rates && original["dias_entrega"].to_s.strip.empty?
        audit << { line: line, original: original, normalized: values, status: status, reasons: reasons }
      end
      counts = audit.map { |row| row[:status] }.tally
      report.update!(status: "completed", rows: audit, summary: {
        total: audit.size, accepted: counts.fetch("ACEPTADO", 0),
        normalized: counts.fetch("NORMALIZADO", 0), rejected: counts.fetch("RECHAZADO", 0)
      })
      report
    end
  rescue CSV::MalformedCSVError, ArgumentError => error
    RateImport.create!(identity.merge(status: "failed", summary: { error: error.message }, rows: []))
  end

  def carrier_record(raw, errors, changes)
    service = { "aéreo" => "air", "terrestre" => "ground" }[key(raw["tipo_servicio"])]
    active = { "si" => true, "sí" => true, "no" => false }[key(raw["activo"])]
    errors << "Tipo de servicio desconocido" unless service
    errors << "Estado activo inválido" if active.nil?
    values = { external_id: raw["carrier_id"].to_s.strip, name: raw["nombre"].to_s.strip,
      service_type: service, active: active }
    changes << "Servicio y estado convertidos a valores consistentes" if service && !active.nil?
    record = Carrier.find_or_initialize_by(external_id: values[:external_id])
    record.assign_attributes(values)
    [values, record]
  end

  def rate_record(raw, errors, changes, report, line)
    carrier_key = ALIASES.fetch(key(raw["paqueteria"]), key(raw["paqueteria"]))
    carrier = Carrier.all.find { |item| key(item.name) == carrier_key }
    errors << "Paquetería fuera del catálogo" unless carrier
    errors << "Paquetería inactiva" if carrier && !carrier.active?
    changes << "Nombre de paquetería normalizado" if carrier && raw["paqueteria"] != carrier.name
    zone_match = raw["zona"].to_s.strip.match(/\A(?:zona\s*|z)?([1-4])\z/i)
    zone = zone_match && zone_match[1].to_i
    errors << "Zona fuera de 1 a 4" unless zone
    changes << "Zona normalizada" if zone && raw["zona"] != zone.to_s
    unit = raw["unidad"].to_s.strip.downcase
    errors << "Unidad de peso ausente o desconocida" unless %w[g kg].include?(unit)
    minimum = capture(errors, "Peso mínimo") { decimal(raw["peso_min"]) }
    maximum = capture(errors, "Peso máximo") { decimal(raw["peso_max"]) }
    if unit == "g"
      minimum /= 1000 if minimum
      maximum /= 1000 if maximum
    end
    changes << "Pesos convertidos a kg" if unit == "g"
    changes << "Unidad normalizada" if unit == "kg" && raw["unidad"] != "kg"
    errors << "Rango de peso inválido" if minimum && maximum && (minimum < 0 || maximum <= minimum)
    errors << "Peso fuera de la capacidad admitida" if [minimum, maximum].compact.any? { |v| v >= 1_000_000_000 }
    errors << "Peso con precisión superior a un gramo" if [minimum, maximum].compact.any? { |v| (v * 1000).frac.nonzero? }
    price = capture(errors, "Precio") { money(raw["precio"]) }
    errors << "Precio ausente, cero o negativo" if price && price <= 0
    changes << "Formato de precio normalizado" if price && raw["precio"] != fixed_money(price)
    date = capture(errors, "Vigencia") { parse_date(raw["vigencia_desde"]) }
    changes << "Fecha normalizada" if date && raw["vigencia_desde"] != date.iso8601
    days = capture(errors, "Plazo") { delivery(raw["dias_entrega"]) } || [nil, nil]
    changes << "Plazo normalizado" if raw["dias_entrega"].to_s.match?(/d[ií]as?/i)
    values = { carrier_id: carrier&.id, zone: zone, weight_min_kg: minimum&.to_s("F"),
      weight_max_kg: maximum&.to_s("F"), price_mxn: price&.to_s("F"),
      delivery_days_min: days[0], delivery_days_max: days[1], effective_from: date&.iso8601 }
    if errors.empty?
      existing = Rate.find_by(values.slice(:carrier_id, :zone, :weight_min_kg, :weight_max_kg, :effective_from))
      errors << "Tarifa duplicada o en conflicto con una tarifa ya registrada" if existing
      overlap = Rate.where(carrier_id: carrier.id, zone: zone)
        .where("weight_min_kg < ? AND weight_max_kg > ?", maximum, minimum)
        .where("effective_until IS NULL OR effective_until > ?", date)
      errors << "Rango superpuesto con una tarifa ya registrada" if !existing && overlap.exists?
    end
    [values, Rate.new(values.merge(rate_import: report, source_line: line))]
  end

  def key(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def capture(errors, label)
    yield
  rescue ArgumentError => error
    errors << "#{label}: #{error.message}"
    nil
  end

  def decimal(raw)
    text = raw.to_s.strip
    raise ArgumentError, "valor numérico inválido" unless text.match?(/\A-?[0-9]+(?:\.[0-9]+)?\z/)
    BigDecimal(text)
  end

  def money(raw)
    text = raw.to_s.strip.delete_prefix("$").sub(/\s*MXN\z/i, "")
    if text.match?(/\A-?[0-9]{1,3}(?:,[0-9]{3})+\.[0-9]{1,2}\z/)
      text = text.delete(",")
    elsif text.match?(/\A-?[0-9]+,[0-9]{1,2}\z/)
      text = text.tr(",", ".")
    end
    raise ArgumentError, "formato monetario ausente o ambiguo" unless text.match?(/\A-?[0-9]+(?:\.[0-9]{1,2})?\z/)
    BigDecimal(text)
  end

  def fixed_money(value)
    integer, fraction = value.to_s("F").split(".")
    integer + "." + fraction.to_s.ljust(2, "0")
  end

  def parse_date(raw)
    text = raw.to_s.strip
    return Date.iso8601(text) if text.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
    if (match = text.match(/\A([0-9]{1,2})\/([0-9]{1,2})\/([0-9]{4})\z/))
      first, second, year = match.captures.map(&:to_i)
      raise ArgumentError, "fecha ambigua" if first <= 12 && second <= 12 && first != second
      day, month = second > 12 ? [second, first] : [first, second]
      return Date.new(year, month, day)
    end
    if (match = text.match(/\A([0-9]{1,2})-ene-([0-9]{4})\z/i))
      return Date.new(match[2].to_i, 1, match[1].to_i)
    end
    raise ArgumentError, "fecha ausente o formato no reconocido"
  end

  def delivery(raw)
    text = raw.to_s.strip.sub(/\s*d[ií]as?\z/i, "")
    return [nil, nil] if text.empty?
    match = text.match(/\A([0-9]+)(?:-([0-9]+))?\z/)
    raise ArgumentError, "formato inválido" unless match
    minimum = match[1].to_i
    maximum = (match[2] || match[1]).to_i
    raise ArgumentError, "rango inválido" if minimum <= 0 || maximum < minimum
    [minimum, maximum]
  end
end
