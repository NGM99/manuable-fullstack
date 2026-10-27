require "uri"

class Quote < ApplicationRecord
  MESSAGES = {
    "pending" => "Estamos procesando tu solicitud.",
    "quoted" => "Estas son las tarifas estimadas disponibles.",
    "no_rates" => "No encontramos tarifas confiables para esta zona. Tu solicitud quedó registrada.",
    "weight_out_of_range" => "No encontramos tarifas para ese peso en esta zona. Tu solicitud quedó registrada.",
    "dimensions_required" => "Necesitamos largo, ancho y alto para cotizar las paqueterías que cobran peso volumétrico.",
    "postal_code_not_found" => "No pudimos localizar uno de los códigos postales. Revisa los datos e intenta de nuevo.",
    "external_service_unavailable" => "El servicio de códigos postales no está disponible. Tu solicitud quedó registrada; intenta de nuevo más tarde.",
    "failed" => "No pudimos completar la cotización. Tu solicitud quedó registrada."
  }.freeze
  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :origin_postal_code, :destination_postal_code, with: ->(value) { value.strip }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :origin_postal_code, :destination_postal_code, format: { with: /\A[0-9]{5}\z/ }
  validates :weight_kg, numericality: { greater_than: 0, less_than: 1_000_000_000 }
  validates :status, inclusion: { in: MESSAGES.keys }
  validates :source, inclusion: { in: %w[web manual] }
  validates :external_reference, uniqueness: true, allow_nil: true
  before_validation :set_validity, on: :create
  validate :weight_precision
  validate :valid_dimensions

  def dimensions_present?
    [length_cm, width_cm, height_cm].all?(&:present?)
  end

  def price_honored?(at: Time.current)
    status == "quoted" && quoted_at <= at && at < valid_until
  end

  def price_status
    return "unavailable" unless status == "quoted"
    return "not_started" if Time.current < quoted_at
    price_honored? ? "valid" : "expired"
  end

  def public_data
    as_json(only: [:id, :origin_postal_code, :destination_postal_code, :weight_kg,
      :distance_km, :zone, :status, :error_code, :options, :quoted_at,
      :length_cm, :width_cm, :height_cm, :source, :external_reference, :valid_until])
      .merge("message" => MESSAGES.fetch(status), "price_honored" => price_honored?, "price_status" => price_status,
        "warnings" => metadata.fetch("warnings", []))
  end

  private

  def set_validity
    self.quoted_at ||= Time.current
    self.valid_until ||= quoted_at + 30.days
  end

  def valid_dimensions
    fields = [:length_cm, :width_cm, :height_cm]
    return if fields.all? { |field| self[field].nil? }
    fields.each do |field|
      raw_value = public_send("#{field}_before_type_cast")
      raw = raw_value.is_a?(BigDecimal) ? raw_value.to_s("F") : raw_value.to_s
      value = self[field]
      unless raw.match?(/\A[0-9]+(?:\.[0-9]{1,3})?\z/) && value && value > 0 && value < 1_000_000
        errors.add(field, "indica las tres medidas positivas en cm, con hasta tres decimales")
      end
    end
  end

  def weight_precision
    raw = weight_kg_before_type_cast
    text = raw.is_a?(BigDecimal) ? raw.to_s("F") : raw.to_s
    unless text.match?(/\A[0-9]+(?:\.[0-9]{1,3})?\z/)
      errors.add(:weight_kg, "usa un número positivo con hasta tres decimales")
    end
  end
end
