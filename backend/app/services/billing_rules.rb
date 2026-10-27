class BillingRules
  def self.load!(path = Rails.root.join("db/data/reglas_cobro.json"))
    config = JSON.parse(File.read(path))
    raise ArgumentError, "Configuración de cobro inválida" unless config.is_a?(Hash)
    Carrier.transaction do
      config.each do |external_id, rules|
        raise ArgumentError, "Las reglas deben ser una lista" unless rules.is_a?(Array)
        dates = []
        rules.each do |rule|
          date = rule.fetch("effective_from")
          raise ArgumentError, "Fecha de regla inválida" unless date.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
          Date.iso8601(date)
          raise ArgumentError, "Fecha de regla duplicada" if dates.include?(date)
          dates << date
          raise ArgumentError, "Método de cobro desconocido" unless %w[real volumetric].include?(rule.fetch("method"))
          if rule["method"] == "volumetric"
            divisor = BigDecimal(rule.fetch("divisor").to_s)
            raise ArgumentError, "Divisor inválido" unless divisor.finite? && divisor > 0
          end
        end
        Carrier.find_by!(external_id: external_id).update!(billing_rules: rules)
      end
    end
  end
end
