class BillableWeight
  def self.call(carrier, quote, date: (quote.quoted_at || Time.current).to_date)
    rule = carrier.billing_rules.select { |item| Date.iso8601(item.fetch("effective_from")) <= date }
      .max_by { |item| item.fetch("effective_from") }
    return { weight: quote.weight_kg, method: "real" } unless rule && rule.fetch("method") == "volumetric"
    return nil unless quote.dimensions_present?

    volumetric = (quote.length_cm * quote.width_cm * quote.height_cm /
      BigDecimal(rule.fetch("divisor").to_s)).ceil(3)
    { weight: [quote.weight_kg, volumetric].max, method: "volumetric",
      volumetric_weight: volumetric, divisor: rule.fetch("divisor") }
  end
end
