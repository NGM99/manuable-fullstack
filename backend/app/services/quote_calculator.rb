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
    candidates = Rate.current.where(zone: zone)
    rates = candidates.where("weight_min_kg < ? AND weight_max_kg >= ?", quote.weight_kg, quote.weight_kg)
      .includes(:carrier).order(:price_mxn, :carrier_id)
    options = rates.map do |rate|
      { carrier_id: rate.carrier_id, carrier_name: rate.carrier.name, service_type: rate.carrier.service_type,
        rate_id: rate.id, price_mxn: rate.price_mxn.to_s("F"), currency: "MXN",
        delivery_days_min: rate.delivery_days_min, delivery_days_max: rate.delivery_days_max,
        billable_weight_kg: quote.weight_kg.to_s("F") }
    end
    status = options.any? ? "quoted" : candidates.exists? ? "weight_out_of_range" : "no_rates"
    { distance_km: distance, zone: zone, options: options, status: status,
      metadata: { origin: origin, destination: destination, distance_method: "haversine" } }
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
