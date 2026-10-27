class QuoteCalculator
  def initialize(lookup: PostalCodeLookup.new)
    @lookup = lookup
  end

  def call(quote)
    origin = @lookup.call(quote.origin_postal_code)
    destination = quote.origin_postal_code == quote.destination_postal_code ?
      origin : @lookup.call(quote.destination_postal_code)
    distance = self.class.distance(origin, destination)
    zone = self.class.zone(distance)
    date = (quote.quoted_at || Time.current).to_date
    candidates = Rate.current(date).where(zone: zone).includes(:carrier).to_a
    warnings = []
    options = candidates.filter_map do |rate|
      billing = BillableWeight.call(rate.carrier, quote, date: date)
      unless billing
        warnings << "Agrega largo, ancho y alto para cotizar con #{rate.carrier.name}."
        next
      end
      weight = billing.fetch(:weight)
      next unless rate.weight_min_kg < weight && weight <= rate.weight_max_kg
      { carrier_id: rate.carrier_id, carrier_name: rate.carrier.name, service_type: rate.carrier.service_type,
        rate_id: rate.id, price_mxn: rate.price_mxn.to_s("F"), currency: "MXN",
        delivery_days_min: rate.delivery_days_min, delivery_days_max: rate.delivery_days_max,
        billable_weight_kg: weight.to_s("F"), billing_method: billing.fetch(:method),
        volumetric_weight_kg: billing[:volumetric_weight]&.to_s("F"), divisor: billing[:divisor] }
    end
    options.sort_by! { |option| [BigDecimal(option.fetch(:price_mxn)), option.fetch(:carrier_id)] }
    status = if options.any?
      "quoted"
    elsif warnings.any?
      "dimensions_required"
    elsif candidates.any?
      "weight_out_of_range"
    else
      "no_rates"
    end
    { distance_km: distance, zone: zone, options: options, status: status,
      metadata: { origin: origin, destination: destination, distance_method: "haversine", warnings: warnings.uniq } }
  rescue PostalCodeLookup::NotFound => error
    { status: "postal_code_not_found", error_code: "postal_code_not_found",
      metadata: { missing_postal_code: error.message } }
  rescue PostalCodeLookup::Unavailable
    { status: "external_service_unavailable", error_code: "postal_service_unavailable" }
  end

  def self.zone(distance)
    return 1 if distance <= 100
    return 2 if distance <= 500
    return 3 if distance <= 1000
    4
  end

  def self.distance(origin, destination)
    radians = Math::PI / 180
    lat1, lat2 = origin.fetch(:latitude) * radians, destination.fetch(:latitude) * radians
    delta_lat = lat2 - lat1
    delta_lon = (destination.fetch(:longitude) - origin.fetch(:longitude)) * radians
    a = (Math.sin(delta_lat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(delta_lon / 2)**2).clamp(0, 1)
    6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end
end
