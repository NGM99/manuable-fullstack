module Api
  module V1
    class QuotesController < ApplicationController
      def create
        quote = Quote.new(params.permit(:email, :origin_postal_code, :destination_postal_code, :weight_kg))
        unless quote.save
          labels = {
            email: "Escribe un correo válido.", origin_postal_code: "Escribe cinco dígitos.",
            destination_postal_code: "Escribe cinco dígitos.", weight_kg: "Usa un peso positivo con hasta tres decimales."
          }
          return render json: { errors: quote.errors.attribute_names.to_h { |field| [field, labels.fetch(field, "Valor inválido.")] } },
            status: :unprocessable_entity
        end
        quote.update!(QuoteCalculator.new.call(quote))
        http_status = case quote.status
        when "postal_code_not_found" then :unprocessable_entity
        when "external_service_unavailable" then :service_unavailable
        else :created
        end
        render json: { quote: quote.public_data }, status: http_status
      rescue ActionDispatch::Http::Parameters::ParseError
        render json: { message: "El cuerpo de la solicitud no contiene JSON válido." }, status: :bad_request
      rescue StandardError => error
        Rails.logger.error("quote_failed request_id=#{request.request_id} error=#{error.class}")
        if quote&.persisted? && quote.status == "pending"
          begin
            quote.update_columns(status: "failed", error_code: "internal_error")
          rescue ActiveRecord::ActiveRecordError
            Rails.logger.error("quote_status_unavailable request_id=#{request.request_id}")
          end
        end
        render json: { message: "No pudimos completar la solicitud. Intenta de nuevo más tarde.",
          request_id: request.request_id }, status: :internal_server_error
      end
    end
  end
end
