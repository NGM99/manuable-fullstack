require "uri"

class Quote < ApplicationRecord
  MESSAGES = {
    "pending" => "Estamos procesando tu solicitud.",
    "quoted" => "Estas son las tarifas estimadas disponibles.",
    "no_rates" => "No encontramos tarifas confiables para esta zona. Tu solicitud quedó registrada.",
    "weight_out_of_range" => "No encontramos tarifas para ese peso en esta zona. Tu solicitud quedó registrada.",
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
  validate :weight_precision

  def public_data
    as_json(only: [:id, :origin_postal_code, :destination_postal_code, :weight_kg,
      :distance_km, :zone, :status, :error_code, :options, :quoted_at]).merge("message" => MESSAGES.fetch(status))
  end

  private

  def weight_precision
    unless weight_kg_before_type_cast.to_s.match?(/\A[0-9]+(?:\.[0-9]{1,3})?\z/)
      errors.add(:weight_kg, "usa un número positivo con hasta tres decimales")
    end
  end
end
